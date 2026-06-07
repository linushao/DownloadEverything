import SwiftUI
import WebKit

struct WebView: View {
    @State private var urlString = "https://www.apple.com"
    @State private var progress: Double = 0.0
    @State private var isLoading = false
    @State private var videos: [VideoItem] = []
    @State private var showVideoPanel = true
    @State private var isExtracting = false
    @State private var pollTimer: Timer?

    @EnvironmentObject var settingsManager: SettingsManager

    private let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        return WKWebView(frame: .zero, configuration: configuration)
    }()

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundColor(.accentColor)

                    TextField("请输入网址", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            loadURL()
                        }

                    Button(action: loadURL) {
                        Image(systemName: "arrow.right")
                    }
                    .buttonStyle(.bordered)

                    Button(action: goBack) {
                        Image(systemName: "arrow.left")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!webView.canGoBack)

                    Button(action: goForward) {
                        Image(systemName: "arrow.right")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!webView.canGoForward)

                    Button(action: reload) {
                        Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Button(action: extractVideos) {
                        Image(systemName: "video")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isExtracting)
                    .help("手动提取视频")
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                if isLoading || progress > 0 {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(height: 2)
                        .animation(.easeInOut, value: progress)
                }

                WebKitView(
                    webView: webView, progress: $progress, isLoading: $isLoading,
                    onPageLoaded: onPageLoaded,
                    onVideosExtracted: { newVideos in
                        videos = newVideos
                        isExtracting = false
                    }
                )
                .edgesIgnoringSafeArea(.bottom)
            }

            VideoListView(
                videos: $videos,
                isExpanded: $showVideoPanel,
                onCopyLink: copyVideoLink,
                onDownload: downloadVideo
            )
            .frame(width: 320)
            .disabled(isExtracting)
        }
        .onAppear {
            loadURL()
        }
    }

    private func loadURL() {
        guard let url = URL(string: urlString) else {
            if let urlWithPrefix = URL(string: "https://\(urlString)") {
                loadURLWithUserAgent(url: urlWithPrefix)
            }
            return
        }
        loadURLWithUserAgent(url: url)
    }

    private func loadURLWithUserAgent(url: URL) {
        var request = URLRequest(url: url)
        let userAgent = settingsManager.currentUserAgent
        if !userAgent.isEmpty {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        videos = []
        stopPolling()
        webView.load(request)
    }

    private func goBack() {
        webView.goBack()
    }

    private func goForward() {
        webView.goForward()
    }

    private func reload() {
        if isLoading {
            webView.stopLoading()
        } else {
            webView.reload()
        }
    }

    private func onPageLoaded() {
        extractVideos()
        startPolling()
    }

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            guard let pollTimer = self.pollTimer, pollTimer === timer else { return }
            self.extractVideos()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func extractVideos() {
        guard !isExtracting else { return }
        isExtracting = true

        let script = """
            (function() {
                var videos = [];
                var videoExtensions = /\\.(mp4|m3u8|webm|mov|flv|avi|wmv|m4v)$/i;
                
                function isVideoURL(url) {
                    return videoExtensions.test(url);
                }
                
                function addVideo(url, title, thumbnail) {
                    if (!url || videos.some(function(v) { return v.url === url; })) {
                        return;
                    }
                    videos.push({ url: url, title: title || '', thumbnail: thumbnail || '' });
                }
                
                var videoTags = document.getElementsByTagName('video');
                for (var i = 0; i < videoTags.length; i++) {
                    var video = videoTags[i];
                    var src = video.src || '';
                    var title = video.title || video.getAttribute('data-title') || '';
                    var poster = video.poster || '';
                    if (src) {
                        addVideo(src, title, poster);
                    }
                    var sources = video.getElementsByTagName('source');
                    for (var j = 0; j < sources.length; j++) {
                        var sourceSrc = sources[j].src || '';
                        addVideo(sourceSrc, title || 'Video ' + (videos.length + 1), poster);
                    }
                }
                
                var mediaElements = document.querySelectorAll('source[type*=\"video\"]');
                for (var k = 0; k < mediaElements.length; k++) {
                    var mediaSrc = mediaElements[k].src || '';
                    var parentTitle = mediaElements[k].parentElement?.title || '';
                    addVideo(mediaSrc, parentTitle || 'Video ' + (videos.length + 1), '');
                }
                
                var allLinks = document.querySelectorAll('a[href]');
                for (var l = 0; l < allLinks.length; l++) {
                    var linkHref = allLinks[l].href || '';
                    var linkText = allLinks[l].textContent || allLinks[l].title || '';
                    if (isVideoURL(linkHref)) {
                        addVideo(linkHref, linkText || 'Video ' + (videos.length + 1), '');
                    }
                }
                
                var allElements = document.getElementsByTagName('*');
                for (var m = 0; m < allElements.length; m++) {
                    var element = allElements[m];
                    for (var n = 0; n < element.attributes.length; n++) {
                        var attr = element.attributes[n];
                        var attrValue = attr.value || '';
                        if (attrValue.indexOf('http') === 0 && isVideoURL(attrValue)) {
                            var elementTitle = element.title || element.textContent || '';
                            addVideo(attrValue, elementTitle || 'Video ' + (videos.length + 1), '');
                        }
                    }
                }
                
                window.webkit.messageHandlers.videoExtractor.postMessage(videos);
            })();
            """

        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("JavaScript execution error: \(error)")
                DispatchQueue.main.async {
                    self.isExtracting = false
                }
            }
        }
    }

    private func copyVideoLink(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    private func downloadVideo(_ url: URL) {
        let fileName = url.lastPathComponent
        let savePath = settingsManager.downloadDirectoryURL
        DownloadManager.shared.addTask(url: url, savePath: savePath, fileName: fileName)
    }
}

struct WebKitView: NSViewRepresentable {
    let webView: WKWebView
    @Binding var progress: Double
    @Binding var isLoading: Bool
    var onPageLoaded: (() -> Void)?
    var onVideosExtracted: (([VideoItem]) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        webView.configuration.userContentController.add(context.coordinator, name: "videoExtractor")
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: WebKitView

        init(_ parent: WebKitView) {
            self.parent = parent
        }

        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            guard let videosArray = message.body as? [[String: String]] else { return }

            let videoItems: [VideoItem] = videosArray.compactMap { videoDict in
                guard let urlString = videoDict["url"], let url = URL(string: urlString) else {
                    return nil
                }
                let title = videoDict["title"] ?? ""
                let thumbnailURL = videoDict["thumbnail"].flatMap { URL(string: $0) }
                return VideoItem(url: url, title: title, thumbnailURL: thumbnailURL)
            }

            DispatchQueue.main.async {
                self.parent.onVideosExtracted?(videoItems)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!)
        {
            parent.isLoading = true
            parent.progress = 0.0
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            parent.progress = 0.5
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.progress = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.parent.isLoading = false
                self.parent.progress = 0.0
                self.parent.onPageLoaded?()
            }
        }

        func webView(
            _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
        ) {
            parent.isLoading = false
            parent.progress = 0.0
        }

        func webView(
            _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            parent.isLoading = false
            parent.progress = 0.0
        }
    }
}

#Preview {
    WebView()
        .frame(height: 600)
}
