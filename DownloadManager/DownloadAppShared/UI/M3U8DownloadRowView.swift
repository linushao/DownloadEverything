//
//  M3U8DownloadRowView.swift
//  DownloadManager
//
//

import SwiftUI

/// M3U8下载任务行视图组件
struct M3U8DownloadRowView: View {

    // MARK: - Properties

    let task: M3U8DownloadTask
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onShare: (() -> Void)?
    let onDetailTap: (() -> Void)?

    @State private var isHovering: Bool = false

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch task.status {
        case .pending:
            return .gray
        case .parsing:
            return .blue
        case .downloadingSegments:
            return .blue
        case .merging:
            return .purple
        case .completed:
            return .green
        case .paused:
            return .orange
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }

    private var actionIcon: String {
        switch task.status {
        case .pending, .parsing:
            return "clock"
        case .downloadingSegments, .merging:
            return "pause.fill"
        case .paused:
            return "play.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "arrow.clockwise"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    // MARK: - Initialization

    init(
        task: M3U8DownloadTask,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        onShare: (() -> Void)? = nil,
        onDetailTap: (() -> Void)? = nil
    ) {
        self.task = task
        self.onPause = onPause
        self.onResume = onResume
        self.onCancel = onCancel
        self.onRemove = onRemove
        self.onShare = onShare
        self.onDetailTap = onDetailTap
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // 文件图标
            statusIcon

            // 文件信息
            fileInfo

            Spacer()

            // 进度和状态
            if task.status == .downloadingSegments || task.status == .merging || task.status == .paused {
                progressSection
            } else {
                statusBadge
            }

            // 操作按钮
            actionButtons
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isHovering ? Color.gray.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    // MARK: - Subviews

    private var statusIcon: some View {
        Image(systemName: "video.fill")
            .font(.title2)
            .foregroundColor(statusColor)
            .frame(width: 32, height: 32)
    }

    private var fileInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(task.fileName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text("HLS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(3)
            }

            Text(task.url.host ?? task.url.absoluteString)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(task.downloadedSegments) / \(task.totalSegments) 分片")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            ProgressView(value: task.progress)
                .frame(minWidth: 60, idealWidth: 100, maxWidth: 150)
                .tint(statusColor)

            HStack(spacing: 4) {
                if task.status == .downloadingSegments {
                    Text(formatSpeed(task.speed))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Text("\(Int(task.progress * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(statusColor)
            }
        }
    }

    private var statusBadge: some View {
        Text(task.status.description)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(4)
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            // 分享按钮（仅在任务完成时显示）
            if task.status == .completed, let onShare = onShare {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .platformHelp("分享")
            }

            // 暂停/恢复按钮
            if task.status == .downloadingSegments || task.status == .merging {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .platformHelp("暂停")
            } else if task.status == .paused {
                Button(action: onResume) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .platformHelp("恢复")
            } else if task.status == .failed {
                Button(action: onResume) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .platformHelp("重试")
            }

            // 取消按钮
            if task.status == .downloadingSegments || task.status == .merging || task.status == .paused || task.status == .pending || task.status == .parsing {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .platformHelp("取消")
            }

            // 删除按钮
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .platformHelp("删除")
        }
        .font(.system(size: 14))
    }

    // MARK: - Helper Methods

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }
}
