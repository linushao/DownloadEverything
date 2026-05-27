import SwiftUI

/// 下载列表视图
struct DownloadListView: View {

    // MARK: - Properties

    @StateObject private var viewModel = DownloadListViewModel()
    @State private var showAddTaskSheet: Bool = false
    @State private var newTaskURL: String = ""
    @State private var selectedFilter: TaskFilter = .all
    @State private var selectedTask: DownloadTask?
    @State private var showDetailSheet: Bool = false
    @State private var shareURL: URL?
    @State private var showFileNotFoundAlert: Bool = false

    // MARK: - Task Filter

    enum TaskFilter: String, CaseIterable {
        case all = "全部"
        case downloading = "下载中"
        case completed = "已完成"
        case failed = "失败"
    }

    // MARK: - Computed Properties

    private var filteredTasks: [DownloadTask] {
        switch selectedFilter {
        case .all:
            return viewModel.tasks
        case .downloading:
            return viewModel.tasks.filter {
                $0.status == .downloading || $0.status == .paused || $0.status == .waiting
            }
        case .completed:
            return viewModel.tasks.filter { $0.status == .completed }
        case .failed:
            return viewModel.tasks.filter { $0.status == .failed }
        }
    }

    // MARK: - Body

    var body: some View {
        #if os(iOS)
            NavigationStack {
                contentView
                    .navigationTitle("下载管理")
                    .navigationBarTitleDisplayMode(.inline)
            }
        #else
            contentView
                .frame(minWidth: 800, minHeight: 600)
        #endif
    }

    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar

            Divider()

            // 筛选器
            filterBar

            Divider()

            // 列表内容
            if filteredTasks.isEmpty {
                emptyStateView
            } else {
                taskList
            }
        }
        .sheet(isPresented: $showAddTaskSheet) {
            addTaskSheet
        }
        .sheet(isPresented: $showDetailSheet) {
            if let task = selectedTask {
                DownloadDetailView(
                    task: task,
                    onPause: { viewModel.pauseTask(task) },
                    onResume: { viewModel.resumeTask(task) },
                    onCancel: { viewModel.cancelTask(task) },
                    onRemove: { viewModel.removeTask(task) },
                    onDismiss: { showDetailSheet = false }
                )
            }
        }
        .sheet(item: $shareURL) { url in
            ActivityView(activityItems: [url])
        }
        .alert("文件不存在", isPresented: $showFileNotFoundAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("要分享的文件不存在，可能已被删除。")
        }
    }

    // MARK: - Subviews

    private var toolbar: some View {
        HStack {
            // 添加按钮
            Button(action: { showAddTaskSheet = true }) {
                Label("添加任务", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            Spacer()

            // 批量操作按钮
            HStack(spacing: 12) {
                Button(action: { viewModel.resumeAllTasks() }) {
                    Label("全部恢复", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)

                Button(action: { viewModel.pauseAllTasks() }) {
                    Label("全部暂停", systemImage: "pause.fill")
                }
                .buttonStyle(.bordered)

                Menu {
                    Button(action: { viewModel.clearCompleted() }) {
                        Label("清空已完成", systemImage: "checkmark.circle")
                    }
                    Button(action: { viewModel.clearFailed() }) {
                        Label("清空失败", systemImage: "exclamationmark.circle")
                    }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var filterBar: some View {
        HStack {
            ForEach(TaskFilter.allCases, id: \.self) { filter in
                Button(action: { selectedFilter = filter }) {
                    Text(filter.rawValue)
                        .font(
                            .system(
                                size: 13, weight: selectedFilter == filter ? .semibold : .regular)
                        )
                        .foregroundColor(selectedFilter == filter ? .blue : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedFilter == filter ? Color.blue.opacity(0.1) : Color.clear
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("\(filteredTasks.count) 个任务")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredTasks) { task in
                    Button {
                        selectedTask = task
                        showDetailSheet = true
                    } label: {
                        DownloadRowView(
                            task: task,
                            onPause: { viewModel.pauseTask(task) },
                            onResume: { viewModel.resumeTask(task) },
                            onCancel: { viewModel.cancelTask(task) },
                            onRemove: { viewModel.removeTask(task) },
                            onShare: task.status == .completed
                                ? {
                                    if task.fileExists {
                                        shareURL = task.fileURL
                                    } else {
                                        showFileNotFoundAlert = true
                                    }
                                }
                                : nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))

            Text("暂无下载任务")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("点击「添加任务」开始下载")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.7))

            Button(action: { showAddTaskSheet = true }) {
                Label("添加任务", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addTaskSheet: some View {
        VStack(spacing: 20) {
            Text("添加下载任务")
                .font(.headline)
                .padding(.top, 20)

            TextField("输入下载链接", text: $newTaskURL)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 200, idealWidth: 400, maxWidth: .infinity)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack(spacing: 16) {
                Button("取消") {
                    newTaskURL = ""
                    showAddTaskSheet = false
                }
                .buttonStyle(.bordered)

                Button("添加") {
                    viewModel.addTask(urlString: newTaskURL)
                    if viewModel.errorMessage == nil {
                        newTaskURL = ""
                        showAddTaskSheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTaskURL.isEmpty)
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
    }
}
