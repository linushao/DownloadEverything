//
//  M3U8DownloadTask.swift
//  DownloadManager
//
//

import Foundation

// MARK: - M3U8DownloadStatus

/// M3U8 下载状态
public enum M3U8DownloadStatus: Int16 {
    /// 待下载
    case pending = 0
    /// 解析中
    case parsing = 1
    /// 下载分片中
    case downloadingSegments = 2
    /// 合并中
    case merging = 3
    /// 已完成
    case completed = 4
    /// 已暂停
    case paused = 5
    /// 失败
    case failed = 6
    /// 已取消
    case cancelled = 7

    public var description: String {
        switch self {
        case .pending:
            return "等待中"
        case .parsing:
            return "解析中"
        case .downloadingSegments:
            return "下载分片中"
        case .merging:
            return "合并中"
        case .completed:
            return "已完成"
        case .paused:
            return "已暂停"
        case .failed:
            return "下载失败"
        case .cancelled:
            return "已取消"
        }
    }
}

// MARK: - M3U8DownloadTask

/// M3U8 下载任务
public final class M3U8DownloadTask: Identifiable, ObservableObject {

    // MARK: - Properties

    public let id = UUID()
    public let taskId: UUID
    public let url: URL
    public let savePath: URL
    public let fileName: String

    @Published public private(set) var status: M3U8DownloadStatus = .pending
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var downloadedSegments: Int = 0
    @Published public private(set) var totalSegments: Int = 0
    @Published public private(set) var speed: Double = 0
    @Published public private(set) var error: Error?

    public var playlist: M3U8Playlist?
    public var tempDirectory: URL

    private var downloadedSegmentIDs: Set<Int> = []
    private let queue = DispatchQueue(label: "com.downloadapp.m3u8task", attributes: .concurrent)
    private var progressHandler: ((Double, Int, Int) -> Void)?
    private var completionHandler: ((Result<URL, Error>) -> Void)?
    private var isCancelled = false

    public let createdAt: Date
    public var updatedAt: Date

    // MARK: - Initialization

    public init(
        taskId: UUID = UUID(),
        url: URL,
        savePath: URL,
        fileName: String? = nil
    ) {
        self.taskId = taskId
        self.url = url
        self.savePath = savePath
        self.fileName =
            fileName ?? url.lastPathComponent.replacingOccurrences(of: ".m3u8", with: ".mp4")
        self.tempDirectory = FileUtils.shared.temporaryDirectory.appendingPathComponent(
            taskId.uuidString, isDirectory: true)
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Public Methods

    /// 设置进度回调
    public func setProgressHandler(_ handler: @escaping (Double, Int, Int) -> Void) {
        self.progressHandler = handler
    }

    /// 设置完成回调
    public func setCompletionHandler(_ handler: @escaping (Result<URL, Error>) -> Void) {
        self.completionHandler = handler
    }

    /// 更新状态
    public func updateStatus(_ status: M3U8DownloadStatus) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.status = status
            self.updatedAt = Date()
        }
    }

    /// 更新进度
    public func updateProgress(downloaded: Int, total: Int) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.downloadedSegments = downloaded
            self.totalSegments = total
            self.progress = total > 0 ? Double(downloaded) / Double(total) : 0
            self.updatedAt = Date()

            self.progressHandler?(self.progress, downloaded, total)
        }
    }

    /// 更新速度
    public func updateSpeed(_ speed: Double) {
        queue.async(flags: .barrier) { [weak self] in
            self?.speed = speed
            self?.updatedAt = Date()
        }
    }

    /// 标记分片已下载
    public func markSegmentDownloaded(_ index: Int) {
        queue.async(flags: .barrier) { [weak self] in
            self?.downloadedSegmentIDs.insert(index)
        }
    }

    /// 检查分片是否已下载
    public func isSegmentDownloaded(_ index: Int) -> Bool {
        var result = false
        queue.sync {
            result = downloadedSegmentIDs.contains(index)
        }
        return result
    }

    /// 完成任务
    public func complete(with url: URL) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.status = .completed
            self.progress = 1.0
            self.updatedAt = Date()
            self.completionHandler?(.success(url))
        }
    }

    /// 任务失败
    public func fail(with error: Error) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.status = .failed
            self.error = error
            self.updatedAt = Date()
            self.completionHandler?(.failure(error))
        }
    }

    /// 取消任务
    public func cancel() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.isCancelled = true
            self.status = .cancelled
            self.updatedAt = Date()
        }
    }

    /// 检查是否已取消
    public var isCancelledFlag: Bool {
        var result = false
        queue.sync {
            result = isCancelled
        }
        return result
    }

    /// 获取临时文件路径
    public func tempSegmentPath(for index: Int) -> URL {
        return tempDirectory.appendingPathComponent("segment_\(index).ts")
    }

    /// 创建临时目录
    public func createTempDirectory() throws {
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true)
    }

    /// 清理临时文件
    public func cleanupTempFiles() {
        try? FileManager.default.removeItem(at: tempDirectory)
    }
}
