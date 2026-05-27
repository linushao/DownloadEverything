import SwiftUI

/// 下载任务详情视图
struct DownloadDetailView: View {

    // MARK: - Properties

    let task: DownloadTask
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onDismiss: () -> Void

    @State private var showDeleteConfirmation: Bool = false
    @State private var showShareSheet: Bool = false

    // MARK: - Computed Properties

    private var progressValue: Double {
        guard task.totalBytes > 0 else { return 0 }
        return Double(task.downloadedBytes) / Double(task.totalBytes)
    }

    private var progressPercentage: String {
        String(format: "%.1f%%", progressValue * 100)
    }

    private var downloadedSize: String {
        formatFileSize(task.downloadedBytes)
    }

    private var totalSize: String {
        formatFileSize(task.totalBytes)
    }

    private var speedText: String {
        if task.status == .downloading && task.speed > 0 {
            return formatFileSize(Int64(task.speed)) + "/s"
        }
        return "-"
    }

    private var statusDescription: String {
        task.status.description
    }

    private var statusColor: Color {
        switch task.status {
        case .waiting:
            return .gray
        case .downloading:
            return .blue
        case .paused:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private var errorMessage: String? {
        task.lastError?.localizedDescription
    }

    // MARK: - Body

    var body: some View {
        #if os(iOS)
            NavigationStack {
                contentView
                    .navigationTitle("任务详情")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("关闭", action: onDismiss)
                        }
                    }
            }
        #else
            contentView
                .frame(
                    minWidth: 400, idealWidth: 500, maxWidth: .infinity,
                    minHeight: 500, idealHeight: 600, maxHeight: .infinity
                )
        #endif
    }

    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            // 头部（仅在macOS上显示）
            #if os(macOS)
                header
                Divider()
            #endif

            // 详情内容
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 基本信息
                    basicInfoSection

                    // 下载进度
                    progressSection

                    // 操作日志
                    logSection
                }
                .padding(20)
            }

            Divider()

            // 底部操作栏
            bottomToolbar
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                onRemove()
                onDismiss()
            }
        } message: {
            Text("确定要删除任务「\(task.fileName)」吗？此操作不可恢复。")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("任务详情")
                    .font(.headline)
                Text(task.fileName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)

            VStack(spacing: 8) {
                InfoRow(label: "文件名称", value: task.fileName)
                InfoRow(label: "下载地址", value: task.url.absoluteString)
                InfoRow(label: "保存路径", value: task.savePath.path)
                InfoRow(label: "文件大小", value: totalSize)
                InfoRow(label: "创建时间", value: formatDate(task.createdAt))
                InfoRow(label: "更新时间", value: formatDate(task.updatedAt))
                InfoRow(label: "重试次数", value: "\(task.retryCount)")
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("下载进度")
                .font(.headline)

            VStack(spacing: 16) {
                // 状态标签
                HStack {
                    Text("状态:")
                        .foregroundColor(.secondary)
                    Text(statusDescription)
                        .foregroundColor(statusColor)
                        .fontWeight(.medium)

                    Spacer()

                    Text("速度:")
                        .foregroundColor(.secondary)
                    Text(speedText)
                        .foregroundColor(.primary)
                }

                // 进度条
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progressValue)
                        .progressViewStyle(.linear)

                    HStack {
                        Text(downloadedSize)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(progressPercentage)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                        Spacer()
                        Text(totalSize)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }

                // 错误信息
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作日志")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                LogEntry(time: task.createdAt, action: "任务创建", icon: "plus.circle")
                if task.updatedAt != task.createdAt {
                    LogEntry(time: task.updatedAt, action: "最后更新", icon: "clock")
                }
                if task.status == .completed {
                    LogEntry(
                        time: task.updatedAt, action: "下载完成", icon: "checkmark.circle.fill",
                        color: .green)
                }
                if task.status == .failed {
                    LogEntry(
                        time: task.updatedAt, action: "下载失败", icon: "xmark.circle.fill", color: .red
                    )
                }
                if task.retryCount > 0 {
                    LogEntry(
                        time: task.updatedAt, action: "已重试 \(task.retryCount) 次",
                        icon: "arrow.clockwise")
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            // 左侧操作按钮
            HStack(spacing: 12) {
                if task.status == .completed {
                    Button(action: {
                        showShareSheet = true
                    }) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }

                if task.status == .downloading {
                    Button(action: onPause) {
                        Label("暂停", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                } else if task.status == .paused || task.status == .failed {
                    Button(action: onResume) {
                        Label("恢复", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                }

                if task.status == .downloading || task.status == .paused {
                    Button(action: onCancel) {
                        Label("取消", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: { showDeleteConfirmation = true }) {
                    Label("删除", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            Spacer()

            // 关闭按钮
            Button("关闭", action: onDismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [task.savePath])
        }
    }

    // MARK: - Helper Methods

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - InfoRow Component

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}

// MARK: - LogEntry Component

private struct LogEntry: View {
    let time: Date
    let action: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)

            Text(action)
                .foregroundColor(.primary)

            Spacer()

            Text(formatTime(time))
                .foregroundColor(.secondary)
        }
        .font(.caption)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

//#Preview {
//    DownloadDetailView(
//        task: DownloadTask(url: URL(string: "https://example.com/file.zip")!, savePath: URL(fileURLWithPath: "/tmp")),
//        onPause: {},
//        onResume: {},
//        onCancel: {},
//        onRemove: {},
//        onDismiss: {}
//    )
//}
