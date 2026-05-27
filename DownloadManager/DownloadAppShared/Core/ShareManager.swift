import CoreData
import Foundation

/// 分享管理器，负责管理文件分享功能
public final class ShareManager {

    // MARK: - Singleton

    public static let shared = ShareManager()

    // MARK: - Properties

    private let repository: ShareRepository
    private let queue = DispatchQueue(
        label: "com.downloadapp.sharemanager", attributes: .concurrent)

    // MARK: - Initialization

    private init() {
        self.repository = ShareRepository()
    }

    // MARK: - Public Methods

    /// 创建分享
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - shareType: 分享类型
    ///   - permission: 权限
    ///   - expiresAt: 过期时间（nil表示永不过期）
    /// - Returns: 分享项
    @discardableResult
    public func createShare(
        filePath: String,
        shareType: ShareType,
        permission: Permission = .readOnly,
        expiresAt: Date? = nil
    ) -> ShareItem {
        let shareItem = ShareItem(
            filePath: filePath,
            shareType: shareType,
            permission: permission,
            expiresAt: expiresAt
        )

        queue.async(flags: .barrier) { [weak self] in
            self?.repository.createShare(
                shareId: shareItem.shareId,
                filePath: shareItem.filePath,
                shareType: shareItem.shareType.rawValue,
                accessToken: shareItem.accessToken,
                permission: shareItem.permission.rawValue,
                expiresAt: shareItem.expiresAt
            )
        }

        return shareItem
    }

    /// 获取所有分享
    /// - Returns: 分享项数组
    public func getAllShares() -> [ShareItem] {
        var result: [ShareItem] = []

        queue.sync {
            let entities = repository.fetchAllShares()
            result = entities.compactMap { ShareItem(entity: $0) }
        }

        return result
    }

    /// 获取有效的分享（未过期）
    /// - Returns: 分享项数组
    public func getValidShares() -> [ShareItem] {
        getAllShares().filter { $0.isValid }
    }

    /// 获取分享详情
    /// - Parameter shareId: 分享ID
    /// - Returns: 分享项
    public func getShare(shareId: UUID) -> ShareItem? {
        var result: ShareItem?

        queue.sync {
            if let entity = repository.fetchShare(by: shareId) {
                result = ShareItem(entity: entity)
            }
        }

        return result
    }

    /// 删除分享
    /// - Parameter shareId: 分享ID
    /// - Returns: 是否成功
    public func deleteShare(shareId: UUID) -> Bool {
        var result = false

        queue.sync {
            if repository.fetchShare(by: shareId) != nil {
                repository.deleteShare(shareId: shareId)
                result = true
            }
        }

        return result
    }

    /// 验证访问令牌
    /// - Parameter token: 访问令牌
    /// - Returns: 是否有效
    public func validateToken(token: String) -> Bool {
        var result = false

        queue.sync {
            if let entity = repository.fetchShare(by: token),
                let shareItem = ShareItem(entity: entity)
            {
                result = shareItem.isValid
            }
        }

        return result
    }

    /// 获取分享项（通过令牌）
    /// - Parameter token: 访问令牌
    /// - Returns: 分享项
    public func getShare(byToken token: String) -> ShareItem? {
        var result: ShareItem?

        queue.sync {
            if let entity = repository.fetchShare(by: token) {
                result = ShareItem(entity: entity)
            }
        }

        return result
    }

    /// 生成分享链接
    /// - Parameter shareId: 分享ID
    /// - Returns: 分享链接
    public func getShareLink(shareId: UUID) -> URL? {
        guard let shareItem = getShare(shareId: shareId) else { return nil }

        var components = URLComponents()
        components.scheme = "downloadapp"
        components.host = "share"
        components.path = "/\(shareItem.accessToken)"

        return components.url
    }

    /// 创建带过期时间的分享（默认7天）
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - shareType: 分享类型
    ///   - permission: 权限
    ///   - days: 过期天数
    /// - Returns: 分享项
    @discardableResult
    public func createShareWithExpiration(
        filePath: String,
        shareType: ShareType,
        permission: Permission = .readOnly,
        days: Int = ShareItem.Config.defaultExpirationDays
    ) -> ShareItem {
        let expiresAt = Calendar.current.date(byAdding: .day, value: days, to: Date())
        return createShare(
            filePath: filePath,
            shareType: shareType,
            permission: permission,
            expiresAt: expiresAt
        )
    }

    /// 清理已过期的分享
    public func cleanExpiredShares() {
        queue.async(flags: .barrier) { [weak self] in
            let entities = self?.repository.fetchAllShares() ?? []
            for entity in entities {
                if let shareItem = ShareItem(entity: entity),
                    shareItem.isExpired
                {
                    self?.repository.deleteShare(shareId: entity.shareId)
                }
            }
        }
    }
}
