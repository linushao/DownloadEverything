import Combine
import Foundation

/// DownloadList视图模型，负责与DownloadManager交互
@MainActor
final class DownloadListViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var tasks: [DownloadTask] = []
    @Published var m3u8Tasks: [M3U8DownloadTask] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let downloadManager: DownloadManager
    private var refreshTimer: Timer?

    // MARK: - Initialization

    init(downloadManager: DownloadManager = .shared) {
        self.downloadManager = downloadManager
        loadTasks()
        startRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// 加载所有任务
    func loadTasks() {
        tasks = downloadManager.getAllTasks()
        m3u8Tasks = downloadManager.m3u8Tasks
    }

    /// 添加下载任务
    func addTask(url: URL, savePath: URL? = nil, fileName: String? = nil) {
        _ = downloadManager.addTask(url: url, savePath: savePath, fileName: fileName)
        loadTasks()
    }

    /// 添加下载任务（通过URL字符串）
    func addTask(urlString: String, savePath: URL? = nil, fileName: String? = nil) {
        guard let url = URL(string: urlString) else {
            errorMessage = "无效的URL"
            return
        }
        addTask(url: url, savePath: savePath, fileName: fileName)
    }

    /// 暂停任务
    func pauseTask(_ task: DownloadTask) {
        _ = downloadManager.pauseTask(taskId: task.taskId)
        loadTasks()
    }

    /// 恢复任务
    func resumeTask(_ task: DownloadTask) {
        _ = downloadManager.resumeTask(taskId: task.taskId)
        loadTasks()
    }

    /// 取消任务
    func cancelTask(_ task: DownloadTask) {
        _ = downloadManager.cancelTask(taskId: task.taskId)
        loadTasks()
    }

    /// 删除任务
    func removeTask(_ task: DownloadTask) {
        _ = downloadManager.removeTask(taskId: task.taskId)
        loadTasks()
    }

    /// 重新下载任务（删除缓存，从头开始下载）
    func restartTask(_ task: DownloadTask) {
        _ = downloadManager.restartTask(taskId: task.taskId)
        loadTasks()
    }

    /// 暂停所有任务
    func pauseAllTasks() {
        downloadManager.pauseAll()
        for task in m3u8Tasks {
            downloadManager.pauseM3U8Task(taskId: task.taskId)
        }
        loadTasks()
    }

    /// 恢复所有任务
    func resumeAllTasks() {
        downloadManager.resumeAll()
        for task in m3u8Tasks {
            downloadManager.resumeM3U8Task(taskId: task.taskId)
        }
        loadTasks()
    }

    /// 清空已完成任务
    func clearCompleted() {
        downloadManager.clearCompletedTasks()
        loadTasks()
    }

    /// 清空失败任务
    func clearFailed() {
        downloadManager.clearFailedTasks()
        loadTasks()
    }

    /// 格式化文件大小
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// 格式化速度
    func formatSpeed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }

    /// 暂停m3u8任务
    func pauseM3U8Task(_ task: M3U8DownloadTask) {
        downloadManager.pauseM3U8Task(taskId: task.taskId)
        loadTasks()
    }

    /// 恢复m3u8任务
    func resumeM3U8Task(_ task: M3U8DownloadTask) {
        downloadManager.resumeM3U8Task(taskId: task.taskId)
        loadTasks()
    }

    /// 取消m3u8任务
    func cancelM3U8Task(_ task: M3U8DownloadTask) {
        downloadManager.cancelM3U8Task(taskId: task.taskId)
        loadTasks()
    }

    /// 删除m3u8任务
    func removeM3U8Task(_ task: M3U8DownloadTask) {
        downloadManager.removeM3U8Task(taskId: task.taskId)
        loadTasks()
    }

    /// 计算进度百分比
    func progressPercentage(for task: DownloadTask) -> Double {
        guard task.totalBytes > 0 else { return 0 }
        return Double(task.downloadedBytes) / Double(task.totalBytes) * 100
    }

    /// 计算m3u8进度百分比
    func progressPercentage(for task: M3U8DownloadTask) -> Double {
        task.progress
    }

    // MARK: - Private Methods

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadTasks()
            }
        }
    }
}
