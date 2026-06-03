import SwiftUI

/// 下载列表视图
struct DownloadListView: View {

    // MARK: - Properties

    @StateObject private var viewModel = DownloadListViewModel()
    @State private var showAddTaskSheet: Bool = false
    @State private var newTaskURL: String = ""
    @State private var suggestedFileName: String = ""
    @State private var isLoadingSuggestedName: Bool = false
    @State private var selectedFilter: TaskFilter = .all
    @State private var selectedTask: DownloadTask?
    @State private var selectedM3U8Task: M3U8DownloadTask?
    @State private var showDetailSheet: Bool = false
    @State private var showM3U8DetailSheet: Bool = false
    @State private var shareURL: URL?
    @State private var showFileNotFoundAlert: Bool = false
    @State private var previewImageURL: URL?
    @State private var previewFileName: String = ""

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let m3u8Parser = M3U8Parser()

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

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
            if isIPad {
                NavigationSplitView {
                    sidebarView
                } detail: {
                    detailView
                }
                .navigationSplitViewStyle(.balanced)
                .sheet(isPresented: $showAddTaskSheet) {
                    addTaskSheet
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
                .sheet(item: $shareURL) { url in
                    #if os(macOS)
                        ActivityView(activityItems: [url], onComplete: { shareURL = nil })
                    #else
                        ActivityView(activityItems: [url])
                    #endif
                }
                .sheet(
                    isPresented: .init(
                        get: { previewImageURL != nil }, set: { if !$0 { previewImageURL = nil } })
                ) {
                    if let url = previewImageURL {
                        ImagePreviewView(imageURL: url, fileName: previewFileName)
                            .presentationDetents([.medium, .large])
                            .presentationDragIndicator(.visible)
                    }
                }
                .alert("文件不存在", isPresented: $showFileNotFoundAlert) {
                    Button("确定", role: .cancel) {}
                } message: {
                    Text("要分享的文件不存在，可能已被删除。")
                }
            } else {
                NavigationStack {
                    contentView
                        .navigationTitle("下载管理")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        #else
            contentView
                .frame(minWidth: 800, minHeight: 600)
        #endif
    }

    // MARK: - iPad Specific Views

    @ViewBuilder
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // 筛选器
            filterBar
                .padding(.top, 8)

            Divider()

            // 列表内容
            let allTasks = filteredTasks + viewModel.m3u8Tasks.map { $0 as Any }
            if allTasks.isEmpty {
                emptyStateView
            } else {
                taskList
            }

            Divider()

            // 工具栏（底部）
            toolbar
                .padding(.bottom, 8)
        }
        .navigationTitle("下载管理")
    }

    @ViewBuilder
    private var detailView: some View {
        if let task = selectedTask {
            DownloadDetailView(
                task: task,
                onPause: { viewModel.pauseTask(task) },
                onResume: { viewModel.resumeTask(task) },
                onCancel: { viewModel.cancelTask(task) },
                onRemove: { deleteFile in
                    viewModel.removeTask(task, deleteOriginalFile: deleteFile)
                    selectedTask = nil
                },
                onDismiss: { selectedTask = nil },
                onRestart: { viewModel.restartTask(task) }
            )
        } else if let task = selectedM3U8Task {
            M3U8DownloadDetailView(
                task: task,
                onPause: { viewModel.pauseM3U8Task(task) },
                onResume: { viewModel.resumeM3U8Task(task) },
                onCancel: { viewModel.cancelM3U8Task(task) },
                onRemove: { deleteFile in
                    viewModel.removeM3U8Task(task, deleteOriginalFile: deleteFile)
                    selectedM3U8Task = nil
                },
                onDismiss: { selectedM3U8Task = nil }
            )
        } else {
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary.opacity(0.5))

                Text("选择任务查看详情")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
            let allTasks = filteredTasks + viewModel.m3u8Tasks.map { $0 as Any }
            if allTasks.isEmpty {
                emptyStateView
            } else {
                taskList
            }
        }
        .sheet(isPresented: $showAddTaskSheet) {
            addTaskSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDetailSheet) {
            if let task = selectedTask {
                DownloadDetailView(
                    task: task,
                    onPause: { viewModel.pauseTask(task) },
                    onResume: { viewModel.resumeTask(task) },
                    onCancel: { viewModel.cancelTask(task) },
                    onRemove: { deleteFile in
                        viewModel.removeTask(task, deleteOriginalFile: deleteFile)
                    },
                    onDismiss: { showDetailSheet = false },
                    onRestart: { viewModel.restartTask(task) }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showM3U8DetailSheet) {
            if let task = selectedM3U8Task {
                M3U8DownloadDetailView(
                    task: task,
                    onPause: { viewModel.pauseM3U8Task(task) },
                    onResume: { viewModel.resumeM3U8Task(task) },
                    onCancel: { viewModel.cancelM3U8Task(task) },
                    onRemove: { deleteFile in
                        viewModel.removeM3U8Task(task, deleteOriginalFile: deleteFile)
                    },
                    onDismiss: { showM3U8DetailSheet = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $shareURL) { url in
            #if os(macOS)
                ActivityView(activityItems: [url], onComplete: { shareURL = nil })
            #else
                ActivityView(activityItems: [url])
            #endif
        }
        .sheet(
            isPresented: .init(
                get: { previewImageURL != nil }, set: { if !$0 { previewImageURL = nil } })
        ) {
            if let url = previewImageURL {
                ImagePreviewView(imageURL: url, fileName: previewFileName)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
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
                    .font(.system(size: 13))
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("AddDownloadButton")

            Spacer()

            // 批量操作按钮
            HStack(spacing: 12) {
                Button(action: { viewModel.resumeAllTasks() }) {
                    Label("全部恢复", systemImage: "play.fill")
                        .font(.system(size: 13))
                }
                .buttonStyle(.bordered)

                Button(action: { viewModel.pauseAllTasks() }) {
                    Label("全部暂停", systemImage: "pause.fill")
                        .font(.system(size: 13))
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
                        .font(.system(size: 13))
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
                // 显示普通任务
                ForEach(filteredTasks) { task in
                    Button {
                        if isIPad {
                            selectedTask = task
                            selectedM3U8Task = nil
                        } else if task.status == .completed && task.fileName.isImageFile {
                            if task.fileExists {
                                previewImageURL = task.fileURL
                                previewFileName = task.fileName
                            } else {
                                showFileNotFoundAlert = true
                            }
                        } else {
                            selectedTask = task
                            showDetailSheet = true
                        }
                    } label: {
                        DownloadRowView(
                            task: task,
                            onPause: { viewModel.pauseTask(task) },
                            onResume: { viewModel.resumeTask(task) },
                            onCancel: { viewModel.cancelTask(task) },
                            onRemove: { deleteFile in
                                viewModel.removeTask(task, deleteOriginalFile: deleteFile)
                            },
                            onShare: task.status == .completed
                                ? {
                                    if task.fileExists {
                                        shareURL = task.fileURL
                                    } else {
                                        showFileNotFoundAlert = true
                                    }
                                }
                                : nil,
                            onPreview: nil,
                            onDetailTap: isIPad
                                ? nil
                                : (task.status == .completed && task.fileName.isImageFile
                                    ? {
                                        selectedTask = task
                                        showDetailSheet = true
                                    }
                                    : nil),
                            onRestart: { viewModel.restartTask(task) }
                        )
                        .background(
                            selectedTask?.id == task.id ? Color.blue.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }

                // 显示m3u8任务
                ForEach(viewModel.m3u8Tasks) { task in
                    Button {
                        if isIPad {
                            selectedM3U8Task = task
                            selectedTask = nil
                        } else {
                            selectedM3U8Task = task
                            showM3U8DetailSheet = true
                        }
                    } label: {
                        M3U8DownloadRowView(
                            task: task,
                            onPause: { viewModel.pauseM3U8Task(task) },
                            onResume: { viewModel.resumeM3U8Task(task) },
                            onCancel: { viewModel.cancelM3U8Task(task) },
                            onRemove: { deleteFile in
                                viewModel.removeM3U8Task(task, deleteOriginalFile: deleteFile)
                            },
                            onShare: task.status == .completed
                                ? {
                                    let fileURL = task.savePath.appendingPathComponent(
                                        task.fileName)
                                    if FileManager.default.fileExists(atPath: fileURL.path) {
                                        shareURL = fileURL
                                    } else {
                                        showFileNotFoundAlert = true
                                    }
                                }
                                : nil,
                            onDetailTap: isIPad
                                ? nil
                                : {
                                    selectedM3U8Task = task
                                    showM3U8DetailSheet = true
                                }
                        )
                        .background(
                            selectedM3U8Task?.id == task.id ? Color.blue.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("DownloadList")
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
                .accessibilityIdentifier("EmptyStateLabel")

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
                .accessibilityIdentifier("URLTextField")
                .onAppear {
                    #if os(iOS)
                        if let clipboardString = UIPasteboard.general.string,
                            !clipboardString.isEmpty,
                            URL(string: clipboardString) != nil,
                            newTaskURL.isEmpty
                        {
                            newTaskURL = clipboardString
                        }
                    #endif
                }
                .onChange(of: newTaskURL) { _, newValue in
                    Task {
                        await loadSuggestedFileName(urlString: newValue)
                    }
                }

            // 显示m3u8识别提示和文件名建议
            if isM3U8URL(newTaskURL) {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                            .foregroundColor(.blue)
                        Text("已识别为 HLS 视频流")
                            .font(.callout)
                            .foregroundColor(.blue)
                        Spacer()
                    }

                    if isLoadingSuggestedName {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在解析文件名...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else if !suggestedFileName.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("建议文件名:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("", text: $suggestedFileName)
                                .textFieldStyle(.roundedBorder)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack(spacing: 16) {
                Button("取消") {
                    newTaskURL = ""
                    suggestedFileName = ""
                    showAddTaskSheet = false
                }
                .buttonStyle(.bordered)

                Button("添加") {
                    let fileName = !suggestedFileName.isEmpty ? suggestedFileName : nil
                    viewModel.addTask(urlString: newTaskURL, fileName: fileName)
                    if viewModel.errorMessage == nil {
                        newTaskURL = ""
                        suggestedFileName = ""
                        showAddTaskSheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTaskURL.isEmpty || isLoadingSuggestedName)
                .accessibilityIdentifier("ConfirmAddButton")
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
    }

    private func isM3U8URL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let pathExtension = url.pathExtension.lowercased()
        return pathExtension == "m3u8" || pathExtension == "m3u"
            || urlString.lowercased().contains("m3u8")
    }

    private func loadSuggestedFileName(urlString: String) async {
        guard !urlString.isEmpty, isM3U8URL(urlString), let url = URL(string: urlString) else {
            suggestedFileName = ""
            return
        }

        // 简单验证模式：只根据 URL 生成建议文件名，不下载解析 m3u8
        let defaultName = url.lastPathComponent
            .replacingOccurrences(of: ".m3u8", with: ".mp4")
            .replacingOccurrences(of: ".m3u", with: ".mp4")
        suggestedFileName = defaultName.isEmpty ? "video.mp4" : defaultName
    }
}
