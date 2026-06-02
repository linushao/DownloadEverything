import Foundation

#if os(iOS)
    import Photos
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

#if os(macOS)
    typealias UIImage = NSImage
#endif

/// 相册项类型
enum PhotoLibraryItemType {
    case image
    case video
}

/// 相册项，代表一张照片或视频
struct PhotoLibraryItem: Identifiable {
    let id: String
    let assetIdentifier: String
    let type: PhotoLibraryItemType
    let creationDate: Date?
    let modificationDate: Date?
    let duration: TimeInterval?

    #if os(iOS)
        init(asset: PHAsset) {
            self.id = asset.localIdentifier
            self.assetIdentifier = asset.localIdentifier
            self.type = asset.mediaType == .video ? .video : .image
            self.creationDate = asset.creationDate
            self.modificationDate = asset.modificationDate
            self.duration = asset.mediaType == .video ? asset.duration : nil
        }
    #else
        init(
            id: String, assetIdentifier: String, type: PhotoLibraryItemType,
            creationDate: Date? = nil, modificationDate: Date? = nil, duration: TimeInterval? = nil
        ) {
            self.id = id
            self.assetIdentifier = assetIdentifier
            self.type = type
            self.creationDate = creationDate
            self.modificationDate = modificationDate
            self.duration = duration
        }
    #endif

    var iconName: String {
        switch type {
        case .image:
            return "photo.fill"
        case .video:
            return "video.fill"
        }
    }

    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var thumbnailURL: URL {
        URL(string: "phasset://\(assetIdentifier)")!
    }
}

/// 相册管理器，用于访问系统相册
class PhotoLibraryManager {

    #if os(iOS)
        private let imageManager = PHImageManager.default()
    #endif

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        #if os(iOS)
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(status == .authorized)
                }
            }
        #else
            completion(false)
        #endif
    }

    var isAuthorized: Bool {
        #if os(iOS)
            PHPhotoLibrary.authorizationStatus() == .authorized
        #else
            false
        #endif
    }

    func fetchAllAssets() -> [PhotoLibraryItem] {
        #if os(iOS)
            guard isAuthorized else { return [] }

            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let assets = PHAsset.fetchAssets(with: options)
            var items: [PhotoLibraryItem] = []

            assets.enumerateObjects { asset, _, _ in
                items.append(PhotoLibraryItem(asset: asset))
            }

            return items
        #else
            return []
        #endif
    }

    func fetchImages() -> [PhotoLibraryItem] {
        #if os(iOS)
            guard isAuthorized else { return [] }

            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.predicate = NSPredicate(
                format: "mediaType == %d", PHAssetMediaType.image.rawValue)

            let assets = PHAsset.fetchAssets(with: options)
            var items: [PhotoLibraryItem] = []

            assets.enumerateObjects { asset, _, _ in
                items.append(PhotoLibraryItem(asset: asset))
            }

            return items
        #else
            return []
        #endif
    }

    func fetchVideos() -> [PhotoLibraryItem] {
        #if os(iOS)
            guard isAuthorized else { return [] }

            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.predicate = NSPredicate(
                format: "mediaType == %d", PHAssetMediaType.video.rawValue)

            let assets = PHAsset.fetchAssets(with: options)
            var items: [PhotoLibraryItem] = []

            assets.enumerateObjects { asset, _, _ in
                items.append(PhotoLibraryItem(asset: asset))
            }

            return items
        #else
            return []
        #endif
    }

    func requestThumbnail(
        assetIdentifier: String,
        targetSize: CGSize = CGSize(width: 200, height: 200),
        completion: @escaping (UIImage?) -> Void
    ) {
        #if os(iOS)
            guard isAuthorized else {
                completion(nil)
                return
            }

            guard
                let asset = PHAsset.fetchAssets(
                    withLocalIdentifiers: [assetIdentifier], options: nil
                ).firstObject
            else {
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
        #else
            completion(nil)
        #endif
    }

    func requestImage(
        assetIdentifier: String,
        completion: @escaping (UIImage?, Data?) -> Void
    ) {
        #if os(iOS)
            guard isAuthorized else {
                completion(nil, nil)
                return
            }

            guard
                let asset = PHAsset.fetchAssets(
                    withLocalIdentifiers: [assetIdentifier], options: nil
                ).firstObject
            else {
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
        #else
            completion(nil, nil)
        #endif
    }

    func exportAsset(
        assetIdentifier: String,
        to destinationURL: URL,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        #if os(iOS)
            guard isAuthorized else {
                completion(
                    false,
                    NSError(
                        domain: "PhotoLibraryManager", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "未授权访问相册"]))
                return
            }

            guard
                let asset = PHAsset.fetchAssets(
                    withLocalIdentifiers: [assetIdentifier], options: nil
                ).firstObject
            else {
                completion(
                    false,
                    NSError(
                        domain: "PhotoLibraryManager", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "资源未找到"]))
                return
            }

            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            guard let resource = PHAssetResource.assetResources(for: asset).first else {
                completion(
                    false,
                    NSError(
                        domain: "PhotoLibraryManager", code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "资源不可用"]))
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
        #else
            completion(
                false,
                NSError(
                    domain: "PhotoLibraryManager", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "macOS不支持相册功能"]))
        #endif
    }
}
