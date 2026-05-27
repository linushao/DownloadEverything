import SwiftUI

/// 分享面板视图
struct SharePanel: View {
    @Environment(\.dismiss) private var dismiss
    
    /// 选中的文件/文件夹
    let selectedFile: FileItem?
    
    /// 选中的相册项
    let selectedPhoto: PhotoLibraryItem?
    
    /// 分享完成回调
    var onShareComplete: ((ShareItem) -> Void)?
    
    @StateObject private var viewModel = SharePanelViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 源选择
                sourcePicker
                
                Divider()
                
                // 内容区域
                contentArea
                
                // 底部操作栏
                if viewModel.selectedItem != nil {
                    Divider()
                    bottomActionBar
                }
            }
            .navigationTitle("分享文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showPermissionSheet) {
                PermissionSheet(viewModel: viewModel)
            }
            .alert("分享成功", isPresented: $viewModel.showSuccessAlert) {
                Button("确定") {
                    if let shareItem = viewModel.createdShareItem {
                        onShareComplete?(shareItem)
                    }
                    dismiss()
                }
            } message: {
                Text("分享链接已生成")
            }
            .task {
                if let file = selectedFile {
                    viewModel.selectFileItem(file)
                } else if let photo = selectedPhoto {
                    viewModel.selectPhotoItem(photo)
                }
            }
        }
    }
}

// MARK: - Source Picker

extension SharePanel {
    private var sourcePicker: some View {
        Picker("来源", selection: $viewModel.selectedSource) {
            Text("文件").tag(ShareSource.files)
            Text("相册").tag(ShareSource.photos)
        }
        .pickerStyle(.segmented)
        .padding()
    }
}

// MARK: - Content Area

extension SharePanel {
    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.selectedSource {
        case .files:
            FileBrowserView(viewModel: viewModel)
        case .photos:
            PhotoBrowserView(viewModel: viewModel)
        }
    }
}

// MARK: - Bottom Action Bar

extension SharePanel {
    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            // 权限和过期时间设置
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("权限")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("权限", selection: $viewModel.selectedPermission) {
                        ForEach(Permission.allCases) { permission in
                            Text(permission.localizedDescription).tag(permission)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("过期时间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("过期时间", selection: $viewModel.selectedExpirationDays) {
                        Text("永不过期").tag(0)
                        Text("1天").tag(1)
                        Text("7天").tag(7)
                        Text("30天").tag(30)
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(.horizontal)
            
            // 创建分享按钮
            Button(action: {
                viewModel.createShare()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("创建分享")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top)
        .background(Color(.systemBackground))
    }
}

// MARK: - File Browser View

struct FileBrowserView: View {
    @ObservedObject var viewModel: SharePanelViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 路径栏
            pathBar
            
            Divider()
            
            // 文件列表
            fileList
        }
    }
    
    private var pathBar: some View {
        HStack {
            Button(action: {
                viewModel.navigateToParent()
            }) {
                Image(systemName: "chevron.left")
            }
            .disabled(viewModel.currentDirectoryParent == nil)
            
            Text(viewModel.currentDirectory?.lastPathComponent ?? "根目录")
                .font(.headline)
            
            Spacer()
        }
        .padding()
    }
    
    private var fileList: some View {
        List(viewModel.currentFiles, selection: $viewModel.selectedFileItem) { item in
            FileItemRow(item: item, isSelected: viewModel.selectedFileItem?.id == item.id)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectFileItem(item)
                }
        }
        .listStyle(.plain)
    }
}

// MARK: - File Item Row

struct FileItemRow: View {
    let item: FileItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                
                if item.type == .file {
                    Text(item.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Photo Browser View

struct PhotoBrowserView: View {
    @ObservedObject var viewModel: SharePanelViewModel
    
    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(viewModel.photos) { item in
                    PhotoItemCell(item: item, viewModel: viewModel)
                }
            }
            .padding(4)
        }
    }
}

// MARK: - Photo Item Cell

struct PhotoItemCell: View {
    let item: PhotoLibraryItem
    @ObservedObject var viewModel: SharePanelViewModel
    @State private var thumbnail: UIImage?
    
    var isSelected: Bool {
        viewModel.selectedPhotoItem?.id == item.id
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
            } else {
                Color(.systemGray5)
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: item.iconName)
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    )
            }
            
            if item.type == .video {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if let duration = item.formattedDuration {
                            Text(duration)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(4)
            }
            
            if isSelected {
                Color.blue.opacity(0.3)
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.title2)
                    .padding(4)
            }
        }
        .frame(height: 120)
        .cornerRadius(4)
        .onTapGesture {
            viewModel.selectPhotoItem(item)
        }
        .task {
            viewModel.loadThumbnail(for: item) { image in
                thumbnail = image
            }
        }
    }
}

// MARK: - Permission Sheet

struct PermissionSheet: View {
    @ObservedObject var viewModel: SharePanelViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if let shareItem = viewModel.createdShareItem {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("分享链接")
                                    .font(.headline)
                                
                                if let shareLink = shareItem.shareLink {
                                    Text(shareLink.absoluteString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.copyShareLink()
                            }) {
                                Image(systemName: "doc.on.doc")
                            }
                        }
                    }
                    
                    Section("分享信息") {
                        LabeledContent("文件路径", value: shareItem.filePath)
                        LabeledContent("权限", value: shareItem.permission.localizedDescription)
                        
                        if let expiresAt = shareItem.expiresAt {
                            LabeledContent("过期时间", value: expiresAt.formatted())
                        } else {
                            LabeledContent("过期时间", value: "永不过期")
                        }
                        
                        LabeledContent("创建时间", value: shareItem.createdAt.formatted())
                    }
                }
            }
            .navigationTitle("分享详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Share Source

enum ShareSource {
    case files
    case photos
}

// MARK: - Share Panel ViewModel

@MainActor
class SharePanelViewModel: ObservableObject {
    @Published var selectedSource: ShareSource = .files
    @Published var selectedPermission: Permission = .readOnly
    @Published var selectedExpirationDays: Int = 7
    @Published var selectedFileItem: FileItem?
    @Published var selectedPhotoItem: PhotoLibraryItem?
    @Published var currentDirectory: URL?
    @Published var currentFiles: [FileItem] = []
    @Published var photos: [PhotoLibraryItem] = []
    @Published var showPermissionSheet = false
    @Published var showSuccessAlert = false
    @Published var createdShareItem: ShareItem?
    
    private let fileExplorer = FileExplorer()
    private let photoLibraryManager = PhotoLibraryManager()
    private var thumbnailCache: [String: UIImage] = [:]
    
    var selectedItem: Any? {
        selectedFileItem ?? selectedPhotoItem
    }
    
    var currentDirectoryParent: URL? {
        currentDirectory.flatMap { fileExplorer.parentDirectory(of: $0) }
    }
    
    init() {
        loadRootDirectory()
        requestPhotoAuthorizationIfNeeded()
    }
    
    func loadRootDirectory() {
        currentDirectory = nil
        currentFiles = fileExplorer.rootDirectories()
    }
    
    func navigateToParent() {
        if let parent = currentDirectoryParent {
            navigate(to: parent)
        } else {
            loadRootDirectory()
        }
    }
    
    func navigate(to directory: URL) {
        currentDirectory = directory
        currentFiles = fileExplorer.contents(of: directory)
    }
    
    func selectFileItem(_ item: FileItem) {
        if item.type == .folder {
            navigate(to: item.url)
        } else {
            if selectedFileItem?.id == item.id {
                selectedFileItem = nil
            } else {
                selectedFileItem = item
                selectedPhotoItem = nil
            }
        }
    }
    
    func selectPhotoItem(_ item: PhotoLibraryItem) {
        if selectedPhotoItem?.id == item.id {
            selectedPhotoItem = nil
        } else {
            selectedPhotoItem = item
            selectedFileItem = nil
        }
    }
    
    func loadThumbnail(for item: PhotoLibraryItem, completion: @escaping (UIImage?) -> Void) {
        if let cached = thumbnailCache[item.id] {
            completion(cached)
            return
        }
        
        photoLibraryManager.requestThumbnail(assetIdentifier: item.assetIdentifier) { [weak self] image in
            if let image = image {
                self?.thumbnailCache[item.id] = image
            }
            completion(image)
        }
    }
    
    func createShare() {
        var filePath: String
        var shareType: ShareType
        
        if let fileItem = selectedFileItem {
            filePath = fileItem.url.path
            shareType = fileItem.type == .folder ? .folder : .file
        } else if let photoItem = selectedPhotoItem {
            // 导出相册资源到临时文件
            let tempURL = FileUtils.shared.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            photoLibraryManager.exportAsset(assetIdentifier: photoItem.assetIdentifier, to: tempURL) { [weak self] success, _ in
                guard let self = self, success else { return }
                
                Task { @MainActor in
                    self.createShare(with: tempURL.path, type: photoItem.type == .video ? .album : .album)
                }
            }
            return
        } else {
            return
        }
        
        createShare(with: filePath, type: shareType)
    }
    
    private func createShare(with filePath: String, type: ShareType) {
        let shareItem: ShareItem
        
        if selectedExpirationDays > 0 {
            shareItem = ShareManager.shared.createShareWithExpiration(
                filePath: filePath,
                shareType: type,
                permission: selectedPermission,
                days: selectedExpirationDays
            )
        } else {
            shareItem = ShareManager.shared.createShare(
                filePath: filePath,
                shareType: type,
                permission: selectedPermission,
                expiresAt: nil
            )
        }
        
        createdShareItem = shareItem
        showSuccessAlert = true
        
        // 延迟显示详情页面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showPermissionSheet = true
        }
    }
    
    func copyShareLink() {
        guard let shareItem = createdShareItem,
              let shareLink = shareItem.shareLink else {
            return
        }
        
        UIPasteboard.general.string = shareLink.absoluteString
    }
    
    private func requestPhotoAuthorizationIfNeeded() {
        if !photoLibraryManager.isAuthorized {
            photoLibraryManager.requestAuthorization { [weak self] authorized in
                if authorized {
                    Task { @MainActor in
                        self?.loadPhotos()
                    }
                }
            }
        } else {
            loadPhotos()
        }
    }
    
    private func loadPhotos() {
        photos = photoLibraryManager.fetchAllAssets()
    }
}

// MARK: - ShareItem Extension

extension ShareItem {
    var shareLink: URL? {
        ShareManager.shared.getShareLink(shareId: shareId)
    }
}

#Preview {
    SharePanel(selectedFile: nil, selectedPhoto: nil)
}

