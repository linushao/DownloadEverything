import Foundation

/// 文件工具类，提供文件操作相关的工具方法
public final class FileUtils {

    public static let shared = FileUtils()

    private init() {}

    // MARK: - 路径操作

    /// 获取文档目录路径
    public var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// 获取临时目录路径
    public var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    /// 获取缓存目录路径
    public var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    /// 获取下载目录路径
    public var downloadsDirectory: URL {
        return documentsDirectory
    }

    // MARK: - 目录操作

    /// 创建目录（如果不存在）
    public func createDirectoryIfNeeded(at url: URL) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            print("Failed to create directory: \(error)")
        }
    }

    /// 删除目录及其内容
    public func removeDirectory(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("Failed to remove directory: \(error)")
            return false
        }
    }

    // MARK: - 文件操作

    /// 检查文件是否存在
    public func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// 获取文件大小
    public func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? Int64
        else {
            return nil
        }
        return size
    }

    /// 删除文件
    public func removeFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("Failed to remove file: \(error)")
            return false
        }
    }

    /// 移动文件
    public func moveFile(from source: URL, to destination: URL) -> Bool {
        do {
            if fileExists(at: destination) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: source, to: destination)
            return true
        } catch {
            print("Failed to move file: \(error)")
            return false
        }
    }

    /// 复制文件
    public func copyFile(from source: URL, to destination: URL) -> Bool {
        do {
            if fileExists(at: destination) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            return true
        } catch {
            print("Failed to copy file: \(error)")
            return false
        }
    }

    // MARK: - 文件名操作

    /// 从URL提取文件名
    public func fileName(from url: URL) -> String {
        url.lastPathComponent
    }

    /// 从URL提取文件扩展名
    public func fileExtension(from url: URL) -> String {
        url.pathExtension
    }

    /// 从URL提取不带扩展名的文件名
    public func fileNameWithoutExtension(from url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    /// 生成唯一文件名
    public func uniqueFileName(for originalName: String, in directory: URL) -> String {
        var fileName = originalName
        var counter = 1

        let nameWithoutExtension = (originalName as NSString).deletingPathExtension
        let fileExtension = (originalName as NSString).pathExtension

        while fileExists(at: directory.appendingPathComponent(fileName)) {
            if fileExtension.isEmpty {
                fileName = "\(nameWithoutExtension) (\(counter))"
            } else {
                fileName = "\(nameWithoutExtension) (\(counter)).\(fileExtension)"
            }
            counter += 1
        }

        return fileName
    }

    // MARK: - 格式化

    /// 格式化文件大小
    public func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// 格式化下载速度
    public func formatSpeed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }
}
