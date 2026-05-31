//
//  M3U8Downloader.swift
//  DownloadManager
//
//

import Alamofire
import Foundation

// MARK: - M3U8DownloaderError

public enum M3U8DownloaderError: LocalizedError {
    case invalidPlaylist
    case downloadFailed(Error)
    case mergeFailed(Error)
    case cancelled
    case noSegments

    public var errorDescription: String? {
        switch self {
        case .invalidPlaylist:
            return "无效的播放列表"
        case .downloadFailed(let error):
            return "下载失败: \(error.localizedDescription)"
        case .mergeFailed(let error):
            return "合并失败: \(error.localizedDescription)"
        case .cancelled:
            return "已取消"
        case .noSegments:
            return "没有分片需要下载"
        }
    }
}

// MARK: - M3U8Downloader

/// M3U8 下载管理器
public final class M3U8Downloader {

    // MARK: - Properties

    private let parser: M3U8Parser
    private let merger: TSMerger
    private let networkService: NetworkService
    private let session: Session

    /// 并发下载数
    public var segmentConcurrency: Int = 2

    /// 最大重试次数
    public var maxRetryCount: Int = 3

    private let queue = DispatchQueue(
        label: "com.downloadapp.m3u8downloader", attributes: .concurrent)
    private var activeTasks: [UUID: M3U8DownloadTask] = [:]

    // MARK: - Initialization

    public init(
        parser: M3U8Parser = M3U8Parser(),
        merger: TSMerger = TSMerger(),
        networkService: NetworkService = .shared
    ) {
        self.parser = parser
        self.merger = merger
        self.networkService = networkService

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 60
        self.session = Session(configuration: configuration)
    }

    // MARK: - Public Methods

    /// 开始下载 M3U8
    /// - Parameters:
    ///   - task: M3U8 下载任务
    public func start(task: M3U8DownloadTask) async {
        activeTasks[task.taskId] = task
        task.updateStatus(.parsing)

        do {
            // 1. 解析 M3U8
            let playlist = try await parser.parse(url: task.url)
            task.playlist = playlist

            // 如果是主播放列表，选择第一个变体流
            var mediaPlaylist = playlist
            if playlist.type == .master, let firstVariant = playlist.variants.first {
                mediaPlaylist = try await parser.parse(url: firstVariant.url)
                task.playlist = mediaPlaylist
            }

            guard !mediaPlaylist.segments.isEmpty else {
                throw M3U8DownloaderError.noSegments
            }

            task.updateStatus(.downloadingSegments)
            try task.createTempDirectory()

            // 2. 下载分片
            try await downloadSegments(task: task, playlist: mediaPlaylist)

            // 3. 合并分片
            task.updateStatus(.merging)
            let outputURL = task.savePath.appendingPathComponent(task.fileName)
            try await merger.merge(
                segments: mediaPlaylist.segments,
                task: task,
                outputURL: outputURL
            )

            // 4. 完成
            task.cleanupTempFiles()
            task.complete(with: outputURL)
            activeTasks.removeValue(forKey: task.taskId)

        } catch {
            if task.isCancelledFlag {
                task.cleanupTempFiles()
                activeTasks.removeValue(forKey: task.taskId)
            } else {
                task.fail(with: error)
                activeTasks.removeValue(forKey: task.taskId)
            }
        }
    }

    /// 暂停下载
    /// - Parameter task: M3U8 下载任务
    public func pause(task: M3U8DownloadTask) {
        task.updateStatus(.paused)
    }

    /// 恢复下载
    /// - Parameter task: M3U8 下载任务
    public func resume(task: M3U8DownloadTask) async {
        guard let playlist = task.playlist else {
            await start(task: task)
            return
        }

        task.updateStatus(.downloadingSegments)

        do {
            try await downloadSegments(task: task, playlist: playlist)

            task.updateStatus(.merging)
            let outputURL = task.savePath.appendingPathComponent(task.fileName)
            try await merger.merge(
                segments: playlist.segments,
                task: task,
                outputURL: outputURL
            )

            task.cleanupTempFiles()
            task.complete(with: outputURL)
            activeTasks.removeValue(forKey: task.taskId)

        } catch {
            task.fail(with: error)
            activeTasks.removeValue(forKey: task.taskId)
        }
    }

    /// 取消下载
    /// - Parameter task: M3U8 下载任务
    public func cancel(task: M3U8DownloadTask) {
        task.cancel()
        activeTasks.removeValue(forKey: task.taskId)
    }

    // MARK: - Private Methods

    private func downloadSegments(task: M3U8DownloadTask, playlist: M3U8Playlist) async throws {
        let segments = playlist.segments
        let totalSegments = segments.count

        var downloadedCount = task.downloadedSegments

        // 使用并发下载
        try await withThrowingTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore(value: segmentConcurrency)

            for (index, segment) in segments.enumerated() {
                if task.isCancelledFlag {
                    throw M3U8DownloaderError.cancelled
                }

                // 检查是否已经下载过
                if task.isSegmentDownloaded(index) {
                    downloadedCount += 1
                    task.updateProgress(downloaded: downloadedCount, total: totalSegments)
                    continue
                }

                await semaphore.wait()

                group.addTask { [weak self] in
                    do {
                        guard let self = self else {
                            await semaphore.signal()
                            return
                        }

                        try await self.downloadSegment(
                            segment: segment,
                            index: index,
                            task: task,
                            retries: self.maxRetryCount
                        )

                        downloadedCount += 1
                        task.updateProgress(downloaded: downloadedCount, total: totalSegments)
                        await semaphore.signal()
                    } catch {
                        await semaphore.signal()
                        throw error
                    }
                }
            }

            try await group.waitForAll()
        }
    }

    private func downloadSegment(
        segment: MediaSegment, index: Int, task: M3U8DownloadTask, retries: Int
    ) async throws {
        let destinationURL = task.tempSegmentPath(for: index)

        // 检查文件是否已存在
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            task.markSegmentDownloaded(index)
            return
        }

        var remainingRetries = retries

        while remainingRetries >= 0 {
            if task.isCancelledFlag {
                throw M3U8DownloaderError.cancelled
            }

            do {
                try await downloadFile(url: segment.url, destination: destinationURL)
                task.markSegmentDownloaded(index)
                return
            } catch {
                remainingRetries -= 1
                if remainingRetries < 0 {
                    throw M3U8DownloaderError.downloadFailed(error)
                }
                // 等待后重试
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1秒
            }
        }
    }

    private func downloadFile(url: URL, destination: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let destination: DownloadRequest.Destination = { _, _ in
                return (destination, [.removePreviousFile, .createIntermediateDirectories])
            }

            session.download(url, to: destination)
                .validate()
                .response { response in
                    switch response.result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
}

// MARK: - AsyncSemaphore

/// 简单的异步信号量
private actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        if value > 0 {
            value -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}
