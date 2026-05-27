import Foundation

/// 下载状态枚举
public enum DownloadStatus: Int16 {
    case waiting = 0
    case downloading = 1
    case paused = 2
    case completed = 3
    case failed = 4

    public var description: String {
        switch self {
        case .waiting: return "等待中"
        case .downloading: return "下载中"
        case .paused: return "已暂停"
        case .completed: return "已完成"
        case .failed: return "下载失败"
        }
    }
}

/// 进度回调类型别名
public typealias ProgressHandler = (Int64, Int64, Double) -> Void

/// 完成回调类型别名
public typealias CompletionHandler = (Result<URL, Error>) -> Void

/// 下载任务类
public final class DownloadTask: NSObject, Identifiable {

    // MARK: - Properties

    public let taskId: UUID
    public let url: URL
    public var fileName: String
    public var savePath: URL
    public var totalBytes: Int64 = 0
    public var downloadedBytes: Int64 = 0
    public var status: DownloadStatus = .waiting
    public var speed: Double = 0
    public var retryCount: Int = 0
    public let createdAt: Date
    public var updatedAt: Date
    public var lastError: Error?

    private var urlSessionTask: URLSessionDownloadTask?

    /// 获取URLSessionTask的taskIdentifier
    var taskIdentifier: Int? {
        return urlSessionTask?.taskIdentifier
    }
    private var progressHandler: ProgressHandler?
    private var completionHandler: CompletionHandler?
    private var resumeData: Data?
    private var speedCalculationTimer: Timer?
    private var lastBytesWritten: Int64 = 0
    private var lastSpeedUpdateTime: Date?
    private var speedLimitTimer: Timer?
    private var isSpeedLimited: Bool = false
    private var speedLimitPauseTime: Date?
    private let speedLimitPauseDuration: TimeInterval = 0.1

    // MARK: - Initialization

    public init(url: URL, savePath: URL, fileName: String? = nil) {
        self.taskId = UUID()
        self.url = url
        self.savePath = savePath
        self.fileName = fileName ?? url.lastPathComponent
        self.createdAt = Date()
        self.updatedAt = Date()
        super.init()
    }
    
    /// 从 CoreData 的 DownloadEntity 初始化
    public init(entity: DownloadEntity) {
        self.taskId = entity.taskId
        self.url = URL(string: entity.url)!
        self.savePath = URL(fileURLWithPath: entity.savePath)
        self.fileName = entity.fileName
        self.totalBytes = entity.totalBytes
        self.downloadedBytes = entity.downloadedBytes
        self.status = DownloadStatus(rawValue: entity.status) ?? .waiting
        self.speed = entity.speed
        self.createdAt = entity.createdAt
        self.updatedAt = entity.updatedAt
        self.resumeData = entity.resumeData
        super.init()
    }

    // MARK: - Public Methods

    /// 开始下载
    public func start(session: URLSession) {
        guard status == .waiting || status == .failed else { return }

        status = .downloading
        updatedAt = Date()

        if let resumeData = self.resumeData {
            urlSessionTask = session.downloadTask(withResumeData: resumeData)
        } else {
            urlSessionTask = session.downloadTask(with: url)
        }

        urlSessionTask?.resume()
        startSpeedCalculation()
        startSpeedLimitTimer()
    }

    /// 暂停下载
    public func pause() {
        guard status == .downloading else { return }

        status = .paused
        updatedAt = Date()

        urlSessionTask?.cancel(byProducingResumeData: { [weak self] data in
            self?.resumeData = data
        })

        stopSpeedCalculation()
    }

    /// 取消下载
    public func cancel() {
        status = .failed
        updatedAt = Date()

        urlSessionTask?.cancel()
        urlSessionTask = nil
        resumeData = nil

        stopSpeedCalculation()
    }

    /// 恢复下载
    public func resume(session: URLSession) {
        guard status == .paused || status == .failed else { return }

        status = .downloading
        updatedAt = Date()
        retryCount += 1

        if let resumeData = self.resumeData {
            urlSessionTask = session.downloadTask(withResumeData: resumeData)
        } else {
            urlSessionTask = session.downloadTask(with: url)
        }

        urlSessionTask?.resume()
        startSpeedCalculation()
        startSpeedLimitTimer()
    }

    /// 设置进度回调
    public func setProgressHandler(_ handler: @escaping ProgressHandler) {
        self.progressHandler = handler
    }

    /// 设置完成回调
    public func setCompletionHandler(_ handler: @escaping CompletionHandler) {
        self.completionHandler = handler
    }

    /// 获取进度（0.0 - 1.0）
    public var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(downloadedBytes) / Double(totalBytes)
    }

    /// 获取resumeData
    public func getResumeData() -> Data? {
        return resumeData
    }

    /// 设置resumeData
    func setResumeData(_ data: Data?) {
        self.resumeData = data
    }

    // MARK: - Internal Methods (Called by DownloadSession)

    func updateDownloadedBytes(_ bytes: Int64, totalBytes: Int64) {
        self.downloadedBytes = bytes
        if totalBytes > 0 {
            self.totalBytes = totalBytes
        }
        self.updatedAt = Date()
    }

    func notifyProgress() {
        progressHandler?(downloadedBytes, totalBytes, speed)
    }

    func notifyCompletion(result: Result<URL, Error>) {
        completionHandler?(result)
    }

    // MARK: - Private Methods

    private func startSpeedCalculation() {
        lastBytesWritten = downloadedBytes
        lastSpeedUpdateTime = Date()

        speedCalculationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.calculateSpeed()
        }
    }

    private func stopSpeedCalculation() {
        speedCalculationTimer?.invalidate()
        speedCalculationTimer = nil
    }

    private func calculateSpeed() {
        guard let lastTime = lastSpeedUpdateTime else { return }

        let now = Date()
        let timeInterval = now.timeIntervalSince(lastTime)

        guard timeInterval > 0 else { return }

        let bytesDiff = downloadedBytes - lastBytesWritten
        speed = Double(bytesDiff) / timeInterval

        lastBytesWritten = downloadedBytes
        lastSpeedUpdateTime = now

        notifyProgress()
    }

    /// 检查速度限制并暂停（如果需要）
    func checkSpeedLimit(maxSpeed: Double) {
        guard maxSpeed > 0 else { return }

        if speed > maxSpeed {
            isSpeedLimited = true
            speedLimitPauseTime = Date()
            urlSessionTask?.suspend()
        } else if isSpeedLimited, let pauseTime = speedLimitPauseTime {
            let elapsed = Date().timeIntervalSince(pauseTime)
            if elapsed >= speedLimitPauseDuration {
                isSpeedLimited = false
                urlSessionTask?.resume()
            }
        }
    }

    /// 重置任务状态用于重试
    func resetForRetry() {
        status = .waiting
        lastError = nil
        resumeData = nil
    }

    /// 标记任务失败
    func markFailed(error: Error?) {
        status = .failed
        lastError = error
        updatedAt = Date()
        stopSpeedCalculation()
        stopSpeedLimitTimer()
    }

    private func startSpeedLimitTimer() {
        speedLimitTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkSpeedLimit(maxSpeed: DownloadManager.shared.speedLimit)
        }
    }

    private func stopSpeedLimitTimer() {
        speedLimitTimer?.invalidate()
        speedLimitTimer = nil
        if isSpeedLimited {
            urlSessionTask?.resume()
            isSpeedLimited = false
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadTask: URLSessionDownloadDelegate {

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 移动文件到目标路径
        let destinationURL = savePath.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)

            status = .completed
            updatedAt = Date()

            stopSpeedLimitTimer()
            notifyCompletion(result: .success(destinationURL))
        } catch {
            status = .failed
            updatedAt = Date()

            stopSpeedLimitTimer()
            notifyCompletion(result: .failure(error))
        }

        stopSpeedCalculation()
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        updateDownloadedBytes(totalBytesWritten, totalBytes: totalBytesExpectedToWrite)
        checkSpeedLimit(maxSpeed: DownloadManager.shared.speedLimit)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let nsError = error as NSError

            // 检查是否是用户取消的
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                // 用户主动取消，不标记为失败
                return
            }

            // 保存resumeData以便断点续传
            if let data = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                self.resumeData = data
            }

            lastError = error
            stopSpeedLimitTimer()
            stopSpeedCalculation()
        }
    }
}
