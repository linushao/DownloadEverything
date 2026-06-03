import SwiftUI

#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

struct ActivityView: View {
    let activityItems: [Any]
    let applicationActivities: [Any]?
    let excludedActivityTypes: [Any]?
    let highlightAirDrop: Bool
    let onComplete: (() -> Void)?

    @State private var isPresented = false

    init(
        activityItems: [Any],
        applicationActivities: [Any]? = nil,
        excludedActivityTypes: [Any]? = nil,
        highlightAirDrop: Bool = true,
        onComplete: (() -> Void)? = nil
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.excludedActivityTypes = excludedActivityTypes
        self.highlightAirDrop = highlightAirDrop
        self.onComplete = onComplete
    }

    var body: some View {
        #if os(iOS)
            ActivityViewControllerWrapper(
                activityItems: activityItems,
                applicationActivities: applicationActivities as? [UIActivity],
                excludedActivityTypes: excludedActivityTypes as? [UIActivity.ActivityType],
                highlightAirDrop: highlightAirDrop
            )
        #else
            VStack(spacing: 20) {
                Text("分享文件")
                    .font(.headline)

                if let url = activityItems.first as? URL, url.isFileURL {
                    Text(url.lastPathComponent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    Button {
                        showSharePanel()
                    } label: {
                        Label("导出", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        onComplete?()
                    } label: {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .frame(width: 300)
        #endif
    }

    #if os(macOS)
        private func showSharePanel() {
            for item in activityItems {
                if let url = item as? URL, url.isFileURL {
                    let panel = NSSavePanel()
                    panel.title = "导出文件"
                    panel.nameFieldStringValue = url.lastPathComponent
                    panel.canCreateDirectories = true
                    panel.begin { result in
                        if result == .OK, let destinationURL = panel.url {
                            do {
                                try FileManager.default.copyItem(at: url, to: destinationURL)
                            } catch {
                                print("文件复制失败: \(error)")
                            }
                        }
                        onComplete?()
                    }
                    break
                }
            }
        }
    #endif
}

#if os(iOS)
    struct ActivityViewControllerWrapper: UIViewControllerRepresentable {
        let activityItems: [Any]
        let applicationActivities: [UIActivity]?
        let excludedActivityTypes: [UIActivity.ActivityType]?
        let highlightAirDrop: Bool

        func makeUIViewController(context: Context) -> UIActivityViewController {
            let validActivityItems = activityItems.filter { item in
                if let url = item as? URL {
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

                if let customExcluded = excludedActivityTypes {
                    excludedTypes.append(contentsOf: customExcluded)
                }

                controller.excludedActivityTypes = excludedTypes
            } else {
                controller.excludedActivityTypes = excludedActivityTypes
            }

            return controller
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context)
        {}
    }
#endif

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView(activityItems: [])
    }
}
