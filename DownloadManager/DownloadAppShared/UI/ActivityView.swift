import SwiftUI
import UIKit

/// 系统分享视图，用于包装 UIActivityViewController
struct ActivityView: UIViewControllerRepresentable {
    /// 要分享的项目
    let activityItems: [Any]
    /// 可选的应用活动类型
    let applicationActivities: [UIActivity]?
    /// 排除的活动类型
    let excludedActivityTypes: [UIActivity.ActivityType]?
    /// 是否突出显示AirDrop（排除一些不常用的分享选项）
    let highlightAirDrop: Bool

    init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil,
        excludedActivityTypes: [UIActivity.ActivityType]? = nil,
        highlightAirDrop: Bool = true
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.excludedActivityTypes = excludedActivityTypes
        self.highlightAirDrop = highlightAirDrop
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // 验证分享项
        let validActivityItems = activityItems.filter { item in
            if let url = item as? URL {
                // 对于文件 URL，检查文件是否存在
                if url.isFileURL {
                    return FileManager.default.fileExists(atPath: url.path)
                }
                return true
            }
            return true
        }

        let controller = UIActivityViewController(
            activityItems: validActivityItems,
            applicationActivities: applicationActivities
        )

        if highlightAirDrop {
            var excludedTypes: [UIActivity.ActivityType] = [
                .addToReadingList,
                .assignToContact,
                .openInIBooks,
                .postToTencentWeibo,
                .postToWeibo,
                .postToVimeo,
                .postToFlickr,
                .postToTwitter,
                .postToFacebook,
                .mail,
                .print,
                .markupAsPDF,
            ]

            // 如果有用户自定义的排除类型，合并进去
            if let customExcluded = excludedActivityTypes {
                excludedTypes.append(contentsOf: customExcluded)
            }

            controller.excludedActivityTypes = excludedTypes
        } else {
            controller.excludedActivityTypes = excludedActivityTypes
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 不需要更新
    }
}

// MARK: - URL Identifiable 扩展
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

#Preview {
    // 预览示例
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("example.txt")
    try? "Hello, World!".write(to: tempURL, atomically: true, encoding: .utf8)

    return ActivityView(activityItems: [tempURL])
}
