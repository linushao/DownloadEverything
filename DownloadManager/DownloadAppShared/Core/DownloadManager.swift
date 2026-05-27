import Foundation

/// 下载管理器，负责管理所有下载任务
public final class DownloadManager: NSObject {

    // MARK: - Singleton

    public static let shared = DownloadManager()

    // MARK: - Properties

    /// 所有下载任务列表
    public private(set) var tasks: [DownloadTask] = []

    /// 最大并发任务数
    public var maxConcurrentTasks: Int = 4

    /// 速度限制（字节/秒），0表示不限速
    public var speedLimit: Double = 0

    /// 最大重试次数
    public var maxRetryCount: Int = 3

    /// 重试延迟（秒）
    public var retryDelay: TimeInterval = 2.0

    private var urlSession: URLSession!
    private var activeTasks: [UUID: DownloadTask] = [:]
    private let queue = DispatchQueue(label: "com.downloadapp.downloadmanager", attributes: .concurrent)

    // MARK: - Initialization

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60 * 60 * 24 // 24小时
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public Methods

    /// 添加下载任务
    @discardableResult
    public func addTask(url: URL, savePath: URL? = nil, fileName: String? = nil) -> UUID {
        let destinationPath = savePath ?? FileUtils.shared.downloadsDirectory

        let task = DownloadTask(
            url: url,
            savePath: destinationPath,
            fileName: fileName ?? url.lastPathComponent
        )

        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.tasks.append(task)
            self.activeTasks[task.taskId] = task
            
            // 检查并发数限制并自动开始下载
            let downloadingCount = self.tasks.filter { $0.status == .downloading }.count
            if downloadingCount < self.maxConcurrentTasks {
                task.start(session: self.urlSession)
            }
        }

        // 等待异步添加完成
        queue.sync { }

        return task.taskId
    }

    /// 移除下载任务
    public func removeTask(taskId: UUID) -> Bool {
        var result = false

        queue.sync {
            if let index = tasks.firstIndex(where: { $0.taskId == taskId }) {
                let task = tasks[index]
                task.cancel()
                tasks.remove(at: index)
                activeTasks.removeValue(forKey: taskId)
                result = true
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
            self?.tasks.removeAll { $0.status == .completed }
        }
    }

    /// 清理失败的任务
    public func clearFailedTasks() {
        queue.async(flags: .barrier) { [weak self] in
            self?.tasks.removeAll { $0.status == .failed }
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
                task.notifyCompletion(result: .failure(task.lastError ?? NSError(domain: "DownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载失败"])))
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

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
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

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let task = findTask(by: downloadTask) else { return }

        queue.async {
            task.updateDownloadedBytes(totalBytesWritten, totalBytes: totalBytesExpectedToWrite)
            task.checkSpeedLimit(maxSpeed: self.speedLimit)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let downloadTaskObj = findTask(by: downloadTask) else { return }

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
