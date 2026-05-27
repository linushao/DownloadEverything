import Foundation

/// 字符串工具类，提供字符串处理相关的工具方法
public final class StringUtils {

    public static let shared = StringUtils()

    private init() {}

    // MARK: - URL处理

    /// 从URL字符串提取文件名
    public func fileName(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return url.lastPathComponent
    }

    /// 从URL字符串提取文件扩展名
    public func fileExtension(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return url.pathExtension.isEmpty ? nil : url.pathExtension
    }

    /// URL编码
    public func urlEncode(_ string: String) -> String? {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }

    /// URL解码
    public func urlDecode(_ string: String) -> String? {
        string.removingPercentEncoding
    }

    // MARK: - 路径处理

    /// 规范化文件路径
    public func normalizePath(_ path: String) -> String {
        path.replacingOccurrences(of: "//", with: "/")
            .replacingOccurrences(of: "/./", with: "/")
    }

    /// 获取路径扩展名
    public func pathExtension(_ path: String) -> String {
        (path as NSString).pathExtension
    }

    /// 获取不带扩展名的文件名
    public func fileNameWithoutExtension(_ path: String) -> String {
        (path as NSString).deletingPathExtension
    }

    // MARK: - 验证

    /// 验证URL格式
    public func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    /// 验证文件名是否合法
    public func isValidFileName(_ fileName: String) -> Bool {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return fileName.rangeOfCharacter(from: invalidCharacters) == nil && !fileName.isEmpty
    }

    // MARK: - 格式化

    /// 截断字符串并添加省略号
    public func truncate(_ string: String, maxLength: Int, trailing: String = "...") -> String {
        guard string.count > maxLength else { return string }
        let endIndex = string.index(string.startIndex, offsetBy: maxLength - trailing.count)
        return String(string[..<endIndex]) + trailing
    }

    /// 将字节数格式化为可读字符串
    public func formatBytes(_ bytes: Int64) -> String {
        FileUtils.shared.formatFileSize(bytes)
    }

    // MARK: - 安全

    /// 清理文件名，移除非法字符
    public func sanitizeFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return fileName.components(separatedBy: invalidCharacters).joined(separator: "_")
    }

    /// 生成随机字符串
    public func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}
