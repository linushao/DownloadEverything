import Foundation
import Photos
import UIKit

/// 相册项类型
enum PhotoLibraryItemType {
    /// 图片
    case image
    /// 视频
    case video
}

/// 相册项，代表一张照片或视频
struct PhotoLibraryItem: Identifiable {
    let id: String
    /// PHAsset本地标识符
    let assetIdentifier: String
    /// 项目类型
    let type: PhotoLibraryItemType
    /// 创建时间
    let creationDate: Date?
    /// 修改时间
    let modificationDate: Date?
    /// 文件大小
    let fileSize: Int64?
    /// 持续时间（视频专用）
    let duration: TimeInterval?
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.assetIdentifier = asset.localIdentifier
        self.type = asset.mediaType == .video ? .video : .image
        self.creationDate = asset.creationDate
        self.modificationDate = asset.modificationDate
        self.fileSize = asset.value(forKey: "fileSize") as? Int64
        self.duration = asset.mediaType == .video ? asset.duration : nil
    }
    
    /// 图标名称
    var iconName: String {
        switch type {
        case .image:
            return "photo.fill"
        case .video:
            return "video.fill"
        }
    }
    
    /// 格式化持续时间
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// 相册管理器，用于访问系统相册
class PhotoLibraryManager {
    
    // MARK: - Properties
    
    private let imageManager = PHImageManager.default()
    
    // MARK: - Authorization
    
    /// 请求相册访问权限
    /// - Parameter completion: 权限回调
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
    
    /// 检查相册访问权限
    var isAuthorized: Bool {
        PHPhotoLibrary.authorizationStatus() == .authorized
    }
    
    // MARK: - Fetch Assets
    
    /// 获取所有相册资源
    /// - Returns: 相册项数组
    func fetchAllAssets() -> [PhotoLibraryItem] {
        guard isAuthorized else { return [] }
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let assets = PHAsset.fetchAssets(with: options)
        var items: [PhotoLibraryItem] = []
        
        assets.enumerateObjects { asset, _, _ in
            items.append(PhotoLibraryItem(asset: asset))
        }
        
        return items
    }
    
    /// 获取图片资源
    /// - Returns: 图片项数组
    func fetchImages() -> [PhotoLibraryItem] {
        guard isAuthorized else { return [] }
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        
        let assets = PHAsset.fetchAssets(with: options)
        var items: [PhotoLibraryItem] = []
        
        assets.enumerateObjects { asset, _, _ in
            items.append(PhotoLibraryItem(asset: asset))
        }
        
        return items
    }
    
    /// 获取视频资源
    /// - Returns: 视频项数组
    func fetchVideos() -> [PhotoLibraryItem] {
        guard isAuthorized else { return [] }
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        
        let assets = PHAsset.fetchAssets(with: options)
        var items: [PhotoLibraryItem] = []
        
        assets.enumerateObjects { asset, _, _ in
            items.append(PhotoLibraryItem(asset: asset))
        }
        
        return items
    }
    
    // MARK: - Load Images/Videos
    
    /// 请求缩略图
    /// - Parameters:
    ///   - assetIdentifier: 资源标识符
    ///   - targetSize: 目标大小
    ///   - completion: 完成回调
    func requestThumbnail(
        assetIdentifier: String,
        targetSize: CGSize = CGSize(width: 200, height: 200),
        completion: @escaping (UIImage?) -> Void
    ) {
        guard isAuthorized else {
            completion(nil)
            return
        }
        
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject else {
            completion(nil)
            return
        }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .exact
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    /// 请求原始图片
    /// - Parameters:
    ///   - assetIdentifier: 资源标识符
    ///   - completion: 完成回调
    func requestImage(
        assetIdentifier: String,
        completion: @escaping (UIImage?, Data?) -> Void
    ) {
        guard isAuthorized else {
            completion(nil, nil)
            return
        }
        
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject else {
            completion(nil, nil)
            return
        }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        imageManager.requestImageDataAndOrientation(
            for: asset,
            options: options
        ) { data, _, _, _ in
            DispatchQueue.main.async {
                if let data = data {
                    let image = UIImage(data: data)
                    completion(image, data)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    /// 导出资源到文件
    /// - Parameters:
    ///   - assetIdentifier: 资源标识符
    ///   - destinationURL: 目标URL
    ///   - completion: 完成回调
    func exportAsset(
        assetIdentifier: String,
        to destinationURL: URL,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard isAuthorized else {
            completion(false, NSError(domain: "PhotoLibraryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未授权访问相册"]))
            return
        }
        
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject else {
            completion(false, NSError(domain: "PhotoLibraryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "资源未找到"]))
            return
        }
        
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        
        guard let resource = PHAssetResource.assetResources(for: asset).first else {
            completion(false, NSError(domain: "PhotoLibraryManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "资源不可用"]))
            return
        }
        
        PHAssetResourceManager.default().writeData(
            for: resource,
            toFile: destinationURL,
            options: options
        ) { error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error)
                } else {
                    completion(true, nil)
                }
            }
        }
    }
}

