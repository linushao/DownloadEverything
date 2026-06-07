import SwiftUI

struct VideoListView: View {
    @Binding var videos: [VideoItem]
    @Binding var isExpanded: Bool

    var onCopyLink: (URL) -> Void
    var onDownload: (URL, String) -> Void
    var onClear: (() -> Void)?
    var onRefresh: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    isExpanded.toggle()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.right" : "chevron.down")
                            .rotationEffect(isExpanded ? .degrees(0) : .degrees(-90))
                            .animation(.easeInOut, value: isExpanded)
                        Text("视频列表")
                            .font(.headline)
                        if !videos.isEmpty {
                            Text("(\(videos.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding()

                Spacer()

                if !videos.isEmpty {
                    Button(action: {
                        onRefresh?()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("刷新视频列表")
                    .padding(.trailing, 8)

                    Button(action: {
                        onClear?()
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .help("清除视频列表")
                    .padding(.trailing, 8)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))

            if isExpanded {
                Divider()

                ScrollView {
                    if videos.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "video")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("当前页面没有找到视频")
                                .foregroundColor(.secondary)
                        }
                        .padding(32)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(videos) { video in
                                VideoItemRow(
                                    video: video,
                                    onCopyLink: onCopyLink,
                                    onDownload: onDownload
                                )
                            }
                        }
                        .padding(8)
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Color(NSColor.separatorColor)
                .frame(width: 1)
                .alignmentGuide(.leading) { $0[.leading] },
            alignment: .leading
        )
    }
}

struct VideoItemRow: View {
    let video: VideoItem
    var onCopyLink: (URL) -> Void
    var onDownload: (URL, String) -> Void

    @State private var copied = false
    @State private var showDownloadDialog = false
    @State private var customFileName = ""

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "film")
                .font(.title)
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.body)
                    .lineLimit(1)

                Text(video.url.absoluteString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .flexibleFrame()

            HStack(spacing: 4) {
                Button(action: {
                    onCopyLink(video.url)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }) {
                    Image(systemName: copied ? "checkmark" : "doc.on.clipboard")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                .help("复制链接")

                Button(action: {
                    customFileName = video.title.isEmpty ? video.url.lastPathComponent : video.title
                    showDownloadDialog = true
                }) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                .help("下载视频")
                .alert("下载视频", isPresented: $showDownloadDialog) {
                    TextField("文件名", text: $customFileName)
                    Button("取消", role: .cancel) {}
                    Button("下载") {
                        if !customFileName.isEmpty {
                            onDownload(video.url, customFileName)
                        }
                    }
                } message: {
                    Text("请输入保存的文件名")
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

extension View {
    func flexibleFrame() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VideoListView(
        videos: .constant([
            VideoItem(url: URL(string: "https://example.com/video1.mp4")!, title: "Sample Video 1"),
            VideoItem(url: URL(string: "https://example.com/video2.mp4")!, title: "Sample Video 2"),
        ]),
        isExpanded: .constant(true),
        onCopyLink: { _ in },
        onDownload: { _, _ in }
    )
    .frame(width: 300, height: 400)
}
