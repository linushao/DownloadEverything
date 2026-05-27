import Foundation
import UIKit

/// 图片缓存工具类，基于NSCache实现轻量级图片缓存
public final class ImageCache {

    public static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB

        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDir.appendingPathComponent("ImageCache", isDirectory: true)

        createCacheDirectoryIfNeeded()
    }

    // MARK: - Public Methods

    /// 获取图片
    public func image(forKey key: String) -> UIImage? {
        // 1. 先从内存缓存获取
        if let image = cache.object(forKey: key as NSString) {
            return image
        }

        // 2. 从磁盘缓存获取
        let fileURL = cacheFileURL(forKey: key)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            cache.setObject(image, forKey: key as NSString)
            return image
        }

        return nil
    }

    /// 存储图片
    public func setImage(_ image: UIImage, forKey key: String) {
        // 1. 存储到内存缓存
        cache.setObject(image, forKey: key as NSString)

        // 2. 异步存储到磁盘缓存
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.cacheFileURL(forKey: key)
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: fileURL)
            }
        }
    }

    /// 移除图片
    public func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)

        let fileURL = cacheFileURL(forKey: key)
        try? fileManager.removeItem(at: fileURL)
    }

    /// 清空所有缓存
    public func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoryIfNeeded()
    }

    /// 清理过期缓存（超过7天的文件）
    public func cleanExpiredCache() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let expirationInterval: TimeInterval = 7 * 24 * 60 * 60 // 7天
            let now = Date()

            guard let files = try? self.fileManager.contentsOfDirectory(
                at: self.cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }

            for fileURL in files {
                guard let attributes = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modificationDate = attributes.contentModificationDate else { continue }

                if now.timeIntervalSince(modificationDate) > expirationInterval {
                    try? self.fileManager.removeItem(at: fileURL)
                }
            }
        }
    }

    /// 获取缓存大小
    public func cacheSize() -> Int64 {
        var size: Int64 = 0

        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        for fileURL in files {
            guard let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = attributes.fileSize else { continue }
            size += Int64(fileSize)
        }

        return size
    }

    // MARK: - Private Methods

    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    private func cacheFileURL(forKey key: String) -> URL {
        let fileName = key.data(using: .utf8)?.base64EncodedString() ?? key
        let safeFileName = fileName.replacingOccurrences(of: "/", with: "_")
        return cacheDirectory.appendingPathComponent(safeFileName)
    }
}
