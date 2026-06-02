import SwiftUI
import Kingfisher

/// 图片预览视图
struct ImagePreviewView: View {
    let imageURL: URL
    let fileName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.black.opacity(0.9)
                    .edgesIgnoringSafeArea(.all)
                
                // 图片
                ScrollView([.horizontal, .vertical]) {
                    KFImage(imageURL)
                        .placeholder {
                            ProgressView()
                                .foregroundColor(.white)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(Color.black)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(fileName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭", action: dismiss.callAsFunction)
                }
                
                // 分享按钮
                ToolbarItem(placement: .navigationBarLeading) {
                    ShareButton(url: imageURL)
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("关闭", action: dismiss.callAsFunction)
                }
                
                // 分享按钮
                ToolbarItem(placement: .secondaryAction) {
                    ShareButton(url: imageURL)
                }
                #endif
            }
        }
    }
}

/// 分享按钮组件
private struct ShareButton: View {
    let url: URL
    @State private var showShareSheet = false
    
    var body: some View {
        Button(action: { showShareSheet = true }) {
            Label("分享", systemImage: "square.and.arrow.up")
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [url])
        }
    }
}

/// 判断文件是否为图片类型
extension URL {
    var isImageFile: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tiff"]
        let ext = pathExtension.lowercased()
        return imageExtensions.contains(ext)
    }
}

/// 判断文件是否为图片类型
extension String {
    var isImageFile: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tiff"]
        let ext = self.lowercased()
        return imageExtensions.contains { ext.hasSuffix($0) }
    }
}
