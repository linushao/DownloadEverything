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
    private let merger: TSMergerProtocol
    private let networkService: NetworkService
    private let session: Session

    /// 并发下载数
    public var segmentConcurrency: Int = 2

    /// 最大重试次数
    public var maxRetryCount: Int = 3

    /// 速度限制（字节/秒），0表示不限速
    public var speedLimit: Double = 0

    /// 切片数量限制，0表示不限制
    public var segmentLimit: Int = 0

    /// 速度限制相关
    private var totalBytesDownloaded: Int64 = 0
    private var lastSpeedUpdateTime: Date = Date()
    private var isSpeedLimited: Bool = false
    private let speedLimitPauseDuration: TimeInterval = 0.1

    private let queue = DispatchQueue(
        label: "com.downloadapp.m3u8downloader", attributes: .concurrent)
    private var activeTasks: [UUID: M3U8DownloadTask] = [:]

    // MARK: - Initialization

    public init(
        parser: M3U8Parser = M3U8Parser(),
        merger: TSMergerProtocol = TSMergerFactory.makeDefault(),
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

            // 2. 下载分片（返回实际下载的分片列表，已应用数量限制）
            let downloadedSegments = try await downloadSegments(task: task, playlist: mediaPlaylist)

            // 3. 合并分片（使用实际下载的分片列表）
            task.updateStatus(.merging)
            let outputURL = task.savePath.appendingPathComponent(task.fileName)
            try await merger.merge(
                segments: downloadedSegments,
                task: task,
                outputURL: outputURL,
                progressHandler: nil
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
            // 下载分片（返回实际下载的分片列表，已应用数量限制）
            let downloadedSegments = try await downloadSegments(task: task, playlist: playlist)

            task.updateStatus(.merging)
            let outputURL = task.savePath.appendingPathComponent(task.fileName)
            try await merger.merge(
                segments: downloadedSegments,
                task: task,
                outputURL: outputURL,
                progressHandler: nil
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

    private func downloadSegments(task: M3U8DownloadTask, playlist: M3U8Playlist) async throws
        -> [MediaSegment]
    {
        var segments = playlist.segments
        let originalTotalSegments = segments.count

        // 应用切片数量限制
        if segmentLimit > 0 && segmentLimit < segments.count {
            segments = Array(segments.prefix(segmentLimit))
        }

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

        return segments
    }

    private func downloadSegment(
        segment: MediaSegment, index: Int, task: M3U8DownloadTask, retries: Int
    ) async throws {
        let destinationURL = task.tempSegmentPath(for: index)

        // 检查文件是否已存在
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("✅ [M3U8下载] 分片 #\(index) 已存在，跳过: \(segment.url.absoluteString)")
            task.markSegmentDownloaded(index)
            return
        }

        var remainingRetries = retries

        while remainingRetries >= 0 {
            if task.isCancelledFlag {
                throw M3U8DownloaderError.cancelled
            }

            do {
                // 更新当前分片信息
                task.updateCurrentSegment(index: index, url: segment.url)
                print("⬇️ [M3U8下载] 开始下载分片 #\(index): \(segment.url.absoluteString)")

                try await downloadFile(url: segment.url, destination: destinationURL)
                task.markSegmentDownloaded(index)
                print("✅ [M3U8下载] 分片 #\(index) 下载完成: \(segment.url.absoluteString)")

                // 检查速度限制
                await checkSpeedLimit()

                // 清空当前分片信息
                task.updateCurrentSegment(index: nil, url: nil)

                return
            } catch {
                remainingRetries -= 1
                if remainingRetries < 0 {
                    print("❌ [M3U8下载] 分片 #\(index) 下载失败: \(segment.url.absoluteString), 错误: \(error.localizedDescription)")
                    // 清空当前分片信息
                    task.updateCurrentSegment(index: nil, url: nil)
                    throw M3U8DownloaderError.downloadFailed(error)
                }
                print("⚠️ [M3U8下载] 分片 #\(index) 下载失败，剩余重试次数 \(remainingRetries): \(segment.url.absoluteString), 错误: \(error.localizedDescription)")
                // 等待后重试
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1秒
            }
        }
    }

    private func downloadFile(url: URL, destination: URL) async throws {
        var accumulatedBytes: Int64 = 0

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            let destination: DownloadRequest.Destination = { _, _ in
                return (destination, [.removePreviousFile, .createIntermediateDirectories])
            }

            session.download(url, to: destination)
                .validate()
                .downloadProgress { progress in
                    accumulatedBytes = progress.completedUnitCount
                }
                .response { [weak self] response in
                    guard let self = self else {
                        continuation.resume(throwing: M3U8DownloaderError.cancelled)
                        return
                    }

                    // 更新总下载字节数
                    self.totalBytesDownloaded += accumulatedBytes

                    switch response.result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }

    /// 检查并应用速度限制
    private func checkSpeedLimit() async {
        guard speedLimit > 0 else { return }

        let now = Date()
        let timeElapsed = now.timeIntervalSince(lastSpeedUpdateTime)

        guard timeElapsed > 0 else { return }

        let currentSpeed = Double(totalBytesDownloaded) / timeElapsed

        if currentSpeed > speedLimit {
            // 超过速度限制，暂停一下
            let excessSpeed = currentSpeed - speedLimit
            let pauseTime = (excessSpeed / speedLimit) * timeElapsed
            try? await Task.sleep(nanoseconds: UInt64(max(0.01, pauseTime) * 1_000_000_000))
        }

        // 重置统计
        lastSpeedUpdateTime = Date()
        totalBytesDownloaded = 0
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
