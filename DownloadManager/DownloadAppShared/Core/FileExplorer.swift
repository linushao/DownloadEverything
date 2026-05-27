import Foundation
import UniformTypeIdentifiers

/// 文件项类型
enum FileItemType {
    /// 文件
    case file
    /// 文件夹
    case folder
}

/// 文件项，代表一个文件或文件夹
struct FileItem: Identifiable, Hashable {
    let id = UUID()
    /// 文件URL
    let url: URL
    /// 文件名
    let name: String
    /// 文件类型
    let type: FileItemType
    /// 文件大小
    let size: Int64?
    /// 创建时间
    let creationDate: Date?
    /// 修改时间
    let modificationDate: Date?
    /// 文件扩展名
    let fileExtension: String?
    /// 是否可分享
    let isSharable: Bool

    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.fileExtension = url.pathExtension.isEmpty ? nil : url.pathExtension

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        self.type = isDirectory.boolValue ? .folder : .file

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.size = attributes?[.size] as? Int64
        self.creationDate = attributes?[.creationDate] as? Date
        self.modificationDate = attributes?[.modificationDate] as? Date

        // 检查是否可分享
        self.isSharable = true
    }

    /// 格式化文件大小
    var formattedSize: String {
        guard let size = size else { return "-" }
        return FileUtils.shared.formatFileSize(size)
    }

    /// 图标名称
    var iconName: String {
        switch type {
        case .folder:
            return "folder.fill"
        case .file:
            return iconForFileType()
        }
    }

    private func iconForFileType() -> String {
        guard let ext = fileExtension?.lowercased() else {
            return "doc.fill"
        }

        switch ext {
        case "pdf":
            return "doc.richtext.fill"
        case "png", "jpg", "jpeg", "gif", "bmp", "tiff":
            return "photo.fill"
        case "mp3", "wav", "aac", "flac", "m4a":
            return "music.note.fill"
        case "mp4", "mov", "avi", "mkv", "wmv":
            return "video.fill"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox.fill"
        case "txt", "rtf":
            return "doc.text.fill"
        case "doc", "docx":
            return "doc.fill"
        case "xls", "xlsx":
            return "tablecells.fill"
        case "ppt", "pptx":
            return "slider.horizontal.3"
        case "swift", "h", "m", "cpp", "c", "java", "py", "js", "html", "css":
            return "curlybraces.square.fill"
        default:
            return "doc.fill"
        }
    }
}

/// 文件浏览器，用于浏览本地文件系统
class FileExplorer {

    // MARK: - Properties

    private let fileManager = FileManager.default

    // MARK: - Public Methods

    /// 获取指定目录下的文件和文件夹
    /// - Parameters:
    ///   - directory: 目录URL
    ///   - showHiddenFiles: 是否显示隐藏文件
    /// - Returns: 文件项数组
    func contents(of directory: URL, showHiddenFiles: Bool = false) -> [FileItem] {
        guard
            let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [
                    .isDirectoryKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey,
                ],
                options: showHiddenFiles ? [] : [.skipsHiddenFiles]
            )
        else {
            return []
        }

        return contents.map { FileItem(url: $0) }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// 获取根目录列表（常用目录）
    /// - Returns: 目录项数组
    func rootDirectories() -> [FileItem] {
        var directories: [URL] = []

        // 下载目录
        directories.append(FileUtils.shared.downloadsDirectory)

        // 文档目录
        directories.append(FileUtils.shared.documentsDirectory)

        // 桌面目录（如果存在）
        if let desktopDirectory = fileManager.urls(for: .desktopDirectory, in: .userDomainMask)
            .first
        {
            directories.append(desktopDirectory)
        }

        return directories.map { FileItem(url: $0) }
    }

    /// 获取父目录
    /// - Parameter directory: 当前目录
    /// - Returns: 父目录URL
    func parentDirectory(of directory: URL) -> URL? {
        let parent = directory.deletingLastPathComponent()
        let rootDirectories = rootDirectories().map { $0.url }

        // 检查是否已经是根目录
        if rootDirectories.contains(directory) {
            return nil
        }

        return parent
    }

    /// 检查URL是否为目录
    /// - Parameter url: 文件URL
    /// - Returns: 是否为目录
    func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    /// 检查文件是否存在
    /// - Parameter url: 文件URL
    /// - Returns: 是否存在
    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
}
