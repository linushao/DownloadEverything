import Foundation

#if os(iOS)
import Kingfisher
import Photos
import UIKit

public struct PHAssetImageDataProvider: ImageDataProvider {
    
    public let assetIdentifier: String
    public let targetSize: CGSize
    public let contentMode: PHImageContentMode
    
    public var cacheKey: String {
        "\(assetIdentifier)_\(targetSize.width)x\(targetSize.height)"
    }
    
    public init(
        assetIdentifier: String, targetSize: CGSize = CGSize(width: 200, height: 200),
        contentMode: PHImageContentMode = .aspectFill
    ) {
        self.assetIdentifier = assetIdentifier
        self.targetSize = targetSize
        self.contentMode = contentMode
    }
    
    public func data(handler: @escaping (Result<Data, Error>) -> Void) {
        let imageManager = PHImageManager.default()
        
        guard
            let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
                .firstObject
        else {
            handler(
                .failure(
                    NSError(
                        domain: "PHAssetImageDataProvider", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "资源未找到"])))
            return
        }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .exact
        
        imageManager.requestImageDataAndOrientation(
            for: asset,
            options: options
        ) { data, _, _, _ in
            if let data = data {
                handler(.success(data))
            } else {
                handler(
                    .failure(
                        NSError(
                            domain: "PHAssetImageDataProvider", code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "无法获取图片数据"])))
            }
        }
    }
}
#endif