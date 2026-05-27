import Foundation

/// 分享类型
public enum ShareType: Int16, CaseIterable, Identifiable {
    /// 单个文件
    case file = 0
    /// 文件夹
    case folder = 1
    /// 相册内容
    case album = 2

    public var id: Int16 { rawValue }

    /// 本地化描述
    public var localizedDescription: String {
        switch self {
        case .file: return "文件"
        case .folder: return "文件夹"
        case .album: return "相册"
        }
    }
}

/// 分享权限
public enum Permission: Int16, CaseIterable, Identifiable {
    /// 只读权限
    case readOnly = 0
    /// 读写权限
    case readWrite = 1

    public var id: Int16 { rawValue }

    /// 本地化描述
    public var localizedDescription: String {
        switch self {
        case .readOnly: return "只读"
        case .readWrite: return "读写"
        }
    }
}

/// 分享项，代表一个分享记录
public struct ShareItem: Identifiable {
    /// Identifiable 协议要求的 id
    public var id: UUID { shareId }
    /// 分享唯一标识
    public let shareId: UUID
    /// 分享文件路径
    public let filePath: String
    /// 分享类型
    public let shareType: ShareType
    /// 访问令牌
    public let accessToken: String
    /// 权限
    public let permission: Permission
    /// 过期时间（nil表示永不过期）
    public let expiresAt: Date?
    /// 创建时间
    public let createdAt: Date

    /// 是否已过期
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    /// 是否有效（未过期）
    public var isValid: Bool {
        !isExpired
    }
    
    /// 从ShareEntity创建
    public init?(entity: ShareEntity) {
        self.shareId = entity.shareId
        self.filePath = entity.filePath
        self.shareType = ShareType(rawValue: entity.shareType) ?? .file
        self.accessToken = entity.accessToken
        self.permission = Permission(rawValue: entity.permission) ?? .readOnly
        self.expiresAt = entity.expiresAt
        self.createdAt = entity.createdAt
    }
    
    /// 创建新的分享项
    public init(
        shareId: UUID = UUID(),
        filePath: String,
        shareType: ShareType,
        permission: Permission,
        expiresAt: Date? = nil
    ) {
        self.shareId = shareId
        self.filePath = filePath
        self.shareType = shareType
        self.accessToken = ShareItem.generateAccessToken()
        self.permission = permission
        self.expiresAt = expiresAt
        self.createdAt = Date()
    }
    
    /// 生成访问令牌
    private static func generateAccessToken() -> String {
        let uuid = UUID().uuidString
        let random = String(format: "%08x", arc4random())
        return "\(uuid)-\(random)".replacingOccurrences(of: "-", with: "")
    }
}

extension ShareItem {
    /// 分享配置常量
    public enum Config {
        /// 默认过期时间（7天）
        public static let defaultExpirationDays: Int = 7
        /// 永不过期标识
        public static let neverExpires: Date? = nil
    }
}
