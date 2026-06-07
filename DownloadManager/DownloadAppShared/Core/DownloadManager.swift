import Combine
import Foundation

/// 下载管理器，负责管理所有下载任务
public final class DownloadManager: NSObject, ObservableObject {

    // MARK: - Singleton

    public static let shared = DownloadManager()

    // MARK: - Properties

    /// 所有下载任务列表
    @Published public private(set) var tasks: [DownloadTask] = []

    /// 是否显示添加下载弹窗
    @Published public var showAddDownloadSheet = false

    /// 最大并发任务数
    public var maxConcurrentTasks: Int = 4

    /// 速度限制（字节/秒），0表示不限速
    public var speedLimit: Double = 0 {
        didSet {
            m3u8Downloader.speedLimit = speedLimit
        }
    }

    /// 最大重试次数
    public var maxRetryCount: Int = 3

    /// 重试延迟（秒）
    public var retryDelay: TimeInterval = 2.0

    // MARK: - M3U8 Properties

    /// M3U8 下载器
    private let m3u8Downloader = M3U8Downloader()

    /// M3U8 切片数量限制，0表示不限制
    public var m3u8SegmentLimit: Int = 0 {
        didSet {
            m3u8Downloader.segmentLimit = m3u8SegmentLimit
        }
    }

    /// M3U8 下载任务列表
    public private(set) var m3u8Tasks: [M3U8DownloadTask] = []

    /// M3U8 解析器
    private let m3u8Parser = M3U8Parser()

    private var urlSession: URLSession!
    private var activeTasks: [UUID: DownloadTask] = [:]
    private let queue = DispatchQueue(
        label: "com.downloadapp.downloadmanager", attributes: .concurrent)

    // MARK: - Initialization

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60 * 60 * 24  // 24小时
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public Methods

    /// 添加下载任务
    @discardableResult
    public func addTask(url: URL, savePath: URL? = nil, fileName: String? = nil) -> UUID {
        if url.pathExtension.lowercased() == "m3u8" {
            return addM3U8Task(url: url, savePath: savePath, fileName: fileName)
        }

        let destinationPath = savePath ?? SettingsManager.shared.downloadDirectoryURL

        let task = DownloadTask(
            url: url,
            savePath: destinationPath,
            fileName: fileName ?? url.lastPathComponent
        )

        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // 检查并发数限制并自动开始下载
            let downloadingCount = self.tasks.filter { $0.status == .downloading }.count
            if downloadingCount < self.maxConcurrentTasks {
                task.start(session: self.urlSession)
            }

            // @Published 属性必须在主线程更新
            DispatchQueue.main.async {
                self.tasks.append(task)
                self.activeTasks[task.taskId] = task
            }
        }

        // 等待异步添加完成
        queue.sync {}

        return task.taskId
    }

    /// 移除下载任务
    public func removeTask(taskId: UUID, deleteOriginalFile: Bool = true) -> Bool {
        var result = false

        queue.sync {
            if let index = tasks.firstIndex(where: { $0.taskId == taskId }) {
                let task = tasks[index]
                task.cancel()
                if deleteOriginalFile {
                    task.deleteLocalCache()
                }
                activeTasks.removeValue(forKey: taskId)
                result = true

                // @Published 属性必须在主线程更新
                DispatchQueue.main.async {
                    self.tasks.remove(at: index)
                }
            }
        }

        return result
    }

    /// 暂停指定任务
    public func pauseTask(taskId: UUID) -> Bool {
        var result = false

        queue.sync {
            if let task = tasks.first(where: { $0.taskId == taskId }) {
                task.pause()
                result = true
            }
        }

        return result
    }

    /// 恢复指定任务
    public func resumeTask(taskId: UUID) -> Bool {
        var result = false

        queue.sync {
            guard let task = tasks.first(where: { $0.taskId == taskId }) else {
                return
            }

            // 检查并发数限制
            let downloadingCount = tasks.filter { $0.status == .downloading }.count
            guard downloadingCount < maxConcurrentTasks else {
                // 达到并发限制，设置为等待状态
                task.status = .waiting
                return
            }

            task.resume(session: urlSession)
            result = true
        }

        return result
    }

    /// 开始指定任务
    public func startTask(taskId: UUID) -> Bool {
        var result = false

        queue.sync {
            guard let task = tasks.first(where: { $0.taskId == taskId }) else {
                return
            }

            // 检查并发数限制
            let downloadingCount = tasks.filter { $0.status == .downloading }.count
            guard downloadingCount < maxConcurrentTasks else {
                task.status = .waiting
                return
            }

            task.start(session: urlSession)
            result = true
        }

        return result
    }

    /// 取消指定任务
    public func cancelTask(taskId: UUID) -> Bool {
        var result = false

        queue.sync {
            if let task = tasks.first(where: { $0.taskId == taskId }) {
                task.cancel()
                result = true
            }
        }

        return result
    }

    /// 重新下载指定任务（删除缓存，从头开始下载）
    public func restartTask(taskId: UUID) -> Bool {
        var result = false

        queue.sync {
            guard let task = tasks.first(where: { $0.taskId == taskId }) else {
                return
            }

            task.cancel()
            task.deleteLocalCache()
            task.resetForRetry()

            let downloadingCount = tasks.filter { $0.status == .downloading }.count
            if downloadingCount < maxConcurrentTasks {
                task.start(session: urlSession)
            } else {
                task.status = .waiting
            }

            result = true
        }

        return result
    }

    /// 取消所有任务
    public func cancelAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.tasks.forEach { $0.cancel() }
        }
    }

    /// 暂停所有任务
    public func pauseAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.tasks.filter { $0.status == .downloading }.forEach { $0.pause() }
        }
    }

    /// 恢复所有任务
    public func resumeAll() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let pausedTasks = self.tasks.filter { $0.status == .paused || $0.status == .failed }
            let downloadingCount = self.tasks.filter { $0.status == .downloading }.count
            let availableSlots = self.maxConcurrentTasks - downloadingCount

            for (index, task) in pausedTasks.prefix(availableSlots).enumerated() {
                task.resume(session: self.urlSession)
            }

            // 剩余任务设置为等待状态
            for task in pausedTasks.dropFirst(availableSlots) {
                task.status = .waiting
            }
        }
    }

    /// 获取任务详情
    public func getTask(taskId: UUID) -> DownloadTask? {
        var result: DownloadTask?

        queue.sync {
            result = tasks.first { $0.taskId == taskId }
        }

        return result
    }

    /// 获取所有任务
    public func getAllTasks() -> [DownloadTask] {
        var result: [DownloadTask] = []

        queue.sync {
            result = tasks
        }

        return result
    }

    /// 获取正在下载的任务
    public func getDownloadingTasks() -> [DownloadTask] {
        var result: [DownloadTask] = []

        queue.sync {
            result = tasks.filter { $0.status == .downloading }
        }

        return result
    }

    /// 获取等待中的任务
    public func getWaitingTasks() -> [DownloadTask] {
        var result: [DownloadTask] = []

        queue.sync {
            result = tasks.filter { $0.status == .waiting }
        }

        return result
    }

    /// 清理已完成的任务
    public func clearCompletedTasks() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            // @Published 属性必须在主线程更新
            DispatchQueue.main.async {
                self.tasks.removeAll { $0.status == .completed }
            }
        }
    }

    /// 清理失败的任务
    public func clearFailedTasks() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            // @Published 属性必须在主线程更新
            DispatchQueue.main.async {
                self.tasks.removeAll { $0.status == .failed }
            }
        }
    }

    // MARK: - Private Methods

    private func startWaitingTasksIfNeeded() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let downloadingCount = self.tasks.filter { $0.status == .downloading }.count
            guard downloadingCount < self.maxConcurrentTasks else { return }

            let waitingTasks = self.tasks.filter { $0.status == .waiting }
            let availableSlots = self.maxConcurrentTasks - downloadingCount

            for task in waitingTasks.prefix(availableSlots) {
                task.start(session: self.urlSession)
            }
        }
    }

    /// 处理任务失败和重试
    private func handleTaskFailure(task: DownloadTask) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // 如果已达到最大重试次数，标记为失败
            if task.retryCount >= self.maxRetryCount {
                task.status = .failed
                task.notifyCompletion(
                    result: .failure(
                        task.lastError
                            ?? NSError(
                                domain: "DownloadManager", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "下载失败"])))
                return
            }

            // 延迟重试
            DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) { [weak self] in
                guard let self = self else { return }

                self.queue.async(flags: .barrier) {
                    // 检查是否被用户取消
                    guard task.status == .downloading || task.status == .waiting else { return }

                    task.resetForRetry()
                    task.resume(session: self.urlSession)
                }
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let task = findTask(by: downloadTask) else { return }

        // 移动文件到目标路径
        let destinationURL = task.savePath.appendingPathComponent(task.fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)

            queue.async(flags: .barrier) {
                task.status = .completed
                task.updatedAt = Date()
                task.notifyCompletion(result: .success(destinationURL))
            }
        } catch {
            queue.async(flags: .barrier) {
                task.status = .failed
                task.lastError = error
                task.updatedAt = Date()
                task.notifyCompletion(result: .failure(error))
            }
        }

        startWaitingTasksIfNeeded()
    }

    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard let task = findTask(by: downloadTask) else { return }

        queue.async {
            task.updateDownloadedBytes(totalBytesWritten, totalBytes: totalBytesExpectedToWrite)
            task.checkSpeedLimit(maxSpeed: self.speedLimit)
        }
    }

    public func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
    ) {
        guard let downloadTask = task as? URLSessionDownloadTask,
            let downloadTaskObj = findTask(by: downloadTask)
        else { return }

        if let error = error {
            let nsError = error as NSError

            // 检查是否是用户取消的
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }

            // 保存resumeData以便断点续传
            if let data = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                downloadTaskObj.setResumeData(data)
            }

            downloadTaskObj.lastError = error
            handleTaskFailure(task: downloadTaskObj)
        }

        startWaitingTasksIfNeeded()
    }

    private func findTask(by urlSessionTask: URLSessionDownloadTask) -> DownloadTask? {
        var result: DownloadTask?

        queue.sync {
            result = tasks.first { $0.taskIdentifier == urlSessionTask.taskIdentifier }
        }

        return result
    }
}

// MARK: - M3U8 Download Extensions

extension DownloadManager {

    /// 添加M3U8下载任务
    /// - Parameters:
    ///   - url: M3U8 URL
    ///   - savePath: 保存路径（可选，默认下载目录）
    ///   - fileName: 文件名（可选，默认从URL生成）
    /// - Returns: 任务ID
    @discardableResult
    public func addM3U8Task(url: URL, savePath: URL? = nil, fileName: String? = nil) -> UUID {
        let destinationPath = savePath ?? SettingsManager.shared.downloadDirectoryURL

        let task = M3U8DownloadTask(
            url: url,
            savePath: destinationPath,
            fileName: fileName
        )

        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.m3u8Tasks.append(task)

            // 开始下载
            Task {
                await self.m3u8Downloader.start(task: task)
            }
        }

        return task.taskId
    }

    /// 检查 URL 是否为 M3U8
    /// - Parameter url: 要检查的 URL
    /// - Returns: 是否为 M3U8
    public func isM3U8URL(_ url: URL) async -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        if pathExtension == "m3u8" || pathExtension == "m3u" {
            return true
        }
        return await m3u8Parser.isValidM3U8(url: url)
    }

    /// 获取 M3U8 任务
    /// - Parameter taskId: 任务 ID
    /// - Returns: M3U8 下载任务
    public func getM3U8Task(taskId: UUID) -> M3U8DownloadTask? {
        var result: M3U8DownloadTask?

        queue.sync {
            result = m3u8Tasks.first { $0.taskId == taskId }
        }

        return result
    }

    /// 暂停M3U8任务
    /// - Parameter taskId: 任务ID
    public func pauseM3U8Task(taskId: UUID) {
        queue.sync {
            if let task = m3u8Tasks.first(where: { $0.taskId == taskId }) {
                m3u8Downloader.pause(task: task)
            }
        }
    }

    /// 恢复M3U8任务
    /// - Parameter taskId: 任务ID
    public func resumeM3U8Task(taskId: UUID) {
        queue.sync {
            if let task = m3u8Tasks.first(where: { $0.taskId == taskId }) {
                Task {
                    await m3u8Downloader.resume(task: task)
                }
            }
        }
    }

    /// 取消M3U8任务
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - deleteOriginalFile: 是否删除原文件
    public func cancelM3U8Task(taskId: UUID, deleteOriginalFile: Bool = true) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            if let index = self.m3u8Tasks.firstIndex(where: { $0.taskId == taskId }) {
                let task = self.m3u8Tasks[index]
                self.m3u8Downloader.cancel(task: task)
                task.cleanupTempFiles()
                if deleteOriginalFile {
                    let finalFileURL = task.savePath.appendingPathComponent(task.fileName)
                    if FileManager.default.fileExists(atPath: finalFileURL.path) {
                        try? FileManager.default.removeItem(at: finalFileURL)
                    }
                }
                self.m3u8Tasks.remove(at: index)
            }
        }
    }

    /// 移除M3U8任务
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - deleteOriginalFile: 是否删除原文件
    public func removeM3U8Task(taskId: UUID, deleteOriginalFile: Bool = true) {
        cancelM3U8Task(taskId: taskId, deleteOriginalFile: deleteOriginalFile)
    }

    // MARK: - SwiftUI Convenience Methods

    /// 开始普通下载（SwiftUI便捷方法）
    /// - Parameters:
    ///   - url: 下载URL
    ///   - destinationURL: 目标保存路径
    public func startDownload(url: URL, destinationURL: URL) {
        let savePath = destinationURL.deletingLastPathComponent()
        let fileName = destinationURL.lastPathComponent
        _ = addTask(url: url, savePath: savePath, fileName: fileName)
    }

    /// 开始M3U8下载（SwiftUI便捷方法）
    /// - Parameters:
    ///   - url: M3U8 URL
    ///   - destinationURL: 目标保存路径
    public func startM3U8Download(url: URL, destinationURL: URL) {
        let savePath = destinationURL.deletingLastPathComponent()
        let fileName = destinationURL.lastPathComponent
        _ = addM3U8Task(url: url, savePath: savePath, fileName: fileName)
    }

    /// 暂停下载任务
    /// - Parameter taskId: 任务ID
    public func pauseDownload(taskId: UUID) {
        pauseTask(taskId: taskId)
        pauseM3U8Task(taskId: taskId)
    }

    /// 恢复下载任务
    /// - Parameter taskId: 任务ID
    public func resumeDownload(taskId: UUID) {
        resumeTask(taskId: taskId)
        resumeM3U8Task(taskId: taskId)
    }

    /// 移除下载任务
    /// - Parameter taskId: 任务ID
    public func removeDownload(taskId: UUID) {
        removeTask(taskId: taskId)
        removeM3U8Task(taskId: taskId)
    }
}
