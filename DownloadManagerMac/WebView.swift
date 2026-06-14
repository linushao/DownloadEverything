import SwiftUI
import WebKit

// MARK: - WebViewManager
class WebViewManager: ObservableObject {
    let webView: WKWebView

    init() {
        let configuration = WKWebViewConfiguration()

        // 注入 M3U8 嗅探脚本（在 document-start 阶段）
        if let m3u8Script = Self.loadM3U8Script() {
            let m3u8UserScript = WKUserScript(
                source: m3u8Script,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            configuration.userContentController.addUserScript(m3u8UserScript)
        }

        let observerScript = """
            (function() {
                var videoExtensions = /\\.(mp4|m3u8|webm|mov|flv|avi|wmv|m4v)$/i;
                var detectedVideos = new Set();
                
                function isVideoURL(url) {
                    return videoExtensions.test(url);
                }
                
                function extractVideosFromElement(element) {
                    var videos = [];
                    
                    if (element.tagName === 'VIDEO') {
                        var src = element.src || '';
                        var title = element.title || element.getAttribute('data-title') || '';
                        var poster = element.poster || '';
                        if (src && !detectedVideos.has(src)) {
                            detectedVideos.add(src);
                            videos.push({ url: src, title: title, thumbnail: poster });
                        }
                        
                        var sources = element.getElementsByTagName('source');
                        for (var j = 0; j < sources.length; j++) {
                            var sourceSrc = sources[j].src || '';
                            if (sourceSrc && !detectedVideos.has(sourceSrc)) {
                                detectedVideos.add(sourceSrc);
                                videos.push({ url: sourceSrc, title: title || 'Video', thumbnail: poster });
                            }
                        }
                    }
                    
                    if (element.tagName === 'SOURCE' && element.type && element.type.indexOf('video') !== -1) {
                        var mediaSrc = element.src || '';
                        if (mediaSrc && !detectedVideos.has(mediaSrc)) {
                            detectedVideos.add(mediaSrc);
                            var parentTitle = element.parentElement?.title || '';
                            videos.push({ url: mediaSrc, title: parentTitle || 'Video', thumbnail: '' });
                        }
                    }
                    
                    if (element.tagName === 'A' && element.href) {
                        var linkHref = element.href || '';
                        if (isVideoURL(linkHref) && !detectedVideos.has(linkHref)) {
                            detectedVideos.add(linkHref);
                            var linkText = element.textContent || element.title || '';
                            videos.push({ url: linkHref, title: linkText || 'Video', thumbnail: '' });
                        }
                    }
                    
                    for (var n = 0; n < element.attributes.length; n++) {
                        var attr = element.attributes[n];
                        var attrValue = attr.value || '';
                        if (attrValue.indexOf('http') === 0 && isVideoURL(attrValue) && !detectedVideos.has(attrValue)) {
                            detectedVideos.add(attrValue);
                            var elementTitle = element.title || element.textContent || '';
                            videos.push({ url: attrValue, title: elementTitle || 'Video', thumbnail: '' });
                        }
                    }
                    
                    return videos;
                }
                
                function processNode(node) {
                    var allVideos = [];
                    
                    if (node.nodeType === 1) {
                        var videosFromNode = extractVideosFromElement(node);
                        allVideos = allVideos.concat(videosFromNode);
                        
                        var children = node.querySelectorAll('video, source[type*="video"], a[href]');
                        for (var i = 0; i < children.length; i++) {
                            var childVideos = extractVideosFromElement(children[i]);
                            allVideos = allVideos.concat(childVideos);
                        }
                    }
                    
                    if (allVideos.length > 0) {
                        window.webkit.messageHandlers.videoExtractor.postMessage(allVideos);
                    }
                }
                
                var observer = new MutationObserver(function(mutations) {
                    mutations.forEach(function(mutation) {
                        mutation.addedNodes.forEach(function(node) {
                            processNode(node);
                        });
                        
                        if (mutation.type === 'attributes') {
                            processNode(mutation.target);
                        }
                    });
                });
                
                observer.observe(document.body, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    attributeFilter: ['src', 'href', 'data-src', 'data-href']
                });
                
                processNode(document.body);
            })();
            """

        let userScript = WKUserScript(
            source: observerScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(userScript)

        self.webView = WKWebView(frame: .zero, configuration: configuration)
    }

    /// 加载 M3U8 嗅探脚本
    private static func loadM3U8Script() -> String? {
        // 获取 M3U8.js 文件路径
        guard
            let bundlePath = Bundle.main.path(
                forResource: "M3U8", ofType: "js", inDirectory: "JsScript"),
            let scriptContent = try? String(contentsOfFile: bundlePath, encoding: .utf8)
        else {
            print("无法加载 M3U8.js 脚本")
            return nil
        }

        // 提取 JavaScript 代码部分（去掉油猴元数据）
        let jsCode = extractJSCode(from: scriptContent)

        // 提供油猴 API 的兼容实现
        let gmAPICompat = generateGMAPICompat()

        return gmAPICompat + "\n" + jsCode
    }

    /// 从油猴脚本中提取 JavaScript 代码
    private static func extractJSCode(from scriptContent: String) -> String {
        // 查找 // ==UserScript== 和 // ==/UserScript== 之间的元数据
        // 然后提取元数据后的代码
        let lines = scriptContent.components(separatedBy: "\n")
        var codeStarted = false
        var codeLines: [String] = []

        for line in lines {
            if line.contains("// ==/UserScript==") {
                codeStarted = true
                continue
            }
            if codeStarted {
                codeLines.append(line)
            }
        }

        return codeLines.joined(separator: "\n")
    }

    /// 生成油猴 API 的兼容实现
    private static func generateGMAPICompat() -> String {
        return """
            // GM API 兼容层 - 为 WebView 提供油猴脚本 API 支持
            (function() {
                // GM_setValue / GM_getValue - 本地存储
                window.GM_setValue = function(key, value) {
                    try {
                        localStorage.setItem('gm_' + key, JSON.stringify(value));
                    } catch(e) {}
                };
                window.GM_getValue = function(key, defaultValue) {
                    try {
                        var value = localStorage.getItem('gm_' + key);
                        return value ? JSON.parse(value) : defaultValue;
                    } catch(e) {
                        return defaultValue;
                    }
                };

                // GM_setClipboard - 复制到剪贴板
                window.GM_setClipboard = function(text) {
                    navigator.clipboard.writeText(text).catch(function(e) {
                        console.error('复制失败:', e);
                    });
                };

                // GM_xmlhttpRequest - 跨域请求
                window.GM_xmlhttpRequest = function(details) {
                    var xhr = new XMLHttpRequest();
                    xhr.open(details.method || 'GET', details.url, true);

                    if (details.headers) {
                        for (var key in details.headers) {
                            xhr.setRequestHeader(key, details.headers[key]);
                        }
                    }

                    xhr.onload = function() {
                        if (details.onload) {
                            details.onload({
                                status: xhr.status,
                                statusText: xhr.statusText,
                                responseText: xhr.responseText,
                                readyState: xhr.readyState
                            });
                        }
                    };

                    xhr.onerror = function() {
                        if (details.onerror) {
                            details.onerror({ error: 'Network error' });
                        }
                    };

                    xhr.send(details.data || null);
                };
            })();
            """
    }
}

struct WebView: View {
    @State private var urlString: String
    @State private var progress: Double = 0.0
    @State private var isLoading = false
    @State private var videos: [VideoItem] = []
    @State private var showVideoPanel = true
    @State private var isExtracting = false
    @StateObject private var webViewManager = WebViewManager()

    @EnvironmentObject var settingsManager: SettingsManager

    init() {
        self._urlString = State(initialValue: SettingsManager.shared.lastWebURL)
    }

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
                    .disabled(!webViewManager.webView.canGoBack)

                    Button(action: goForward) {
                        Image(systemName: "arrow.right")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!webViewManager.webView.canGoForward)

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
                    webView: webViewManager.webView, progress: $progress, isLoading: $isLoading,
                    onPageLoaded: onPageLoaded,
                    onVideosExtracted: { newVideos in
                        videos = newVideos
                        isExtracting = false
                    },
                    onNewVideosFound: { newVideos in
                        for video in newVideos {
                            if !videos.contains(where: { $0.url == video.url }) {
                                videos.append(video)
                            }
                        }
                    }
                )
                .edgesIgnoringSafeArea(.bottom)
            }

            VideoListView(
                videos: $videos,
                isExpanded: $showVideoPanel,
                onCopyLink: copyVideoLink,
                onDownload: downloadVideo,
                onClear: clearVideoList,
                onRefresh: refreshVideoList
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
                settingsManager.lastWebURL = "https://\(urlString)"
                loadURLWithUserAgent(url: urlWithPrefix)
            }
            return
        }
        settingsManager.lastWebURL = urlString
        loadURLWithUserAgent(url: url)
    }

    private func loadURLWithUserAgent(url: URL) {
        var request = URLRequest(url: url)
        let userAgent = settingsManager.currentUserAgent
        if !userAgent.isEmpty {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        videos = []
        webViewManager.webView.load(request)
    }

    private func goBack() {
        webViewManager.webView.goBack()
    }

    private func goForward() {
        webViewManager.webView.goForward()
    }

    private func reload() {
        if isLoading {
            webViewManager.webView.stopLoading()
        } else {
            webViewManager.webView.reload()
        }
    }

    private func onPageLoaded() {
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
                
                return videos;
            })();
            """

        webViewManager.webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("JavaScript execution error: \(error)")
            } else if let videosArray = result as? [[String: String]] {
                let newVideos: [VideoItem] = videosArray.compactMap { videoDict in
                    guard let urlString = videoDict["url"], let url = URL(string: urlString) else {
                        return nil
                    }
                    let title = videoDict["title"] ?? ""
                    let thumbnailURL = videoDict["thumbnail"].flatMap { URL(string: $0) }
                    return VideoItem(url: url, title: title, thumbnailURL: thumbnailURL)
                }

                DispatchQueue.main.async {
                    for video in newVideos {
                        if !self.videos.contains(where: { $0.url == video.url }) {
                            self.videos.append(video)
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self.isExtracting = false
            }
        }
    }

    private func copyVideoLink(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    private func downloadVideo(_ url: URL, _ fileName: String) {
        let savePath = settingsManager.downloadDirectoryURL
        DownloadManager.shared.addTask(url: url, savePath: savePath, fileName: fileName)
    }

    private func refreshVideoList() {
        extractVideos()
    }

    private func clearVideoList() {
        videos = []
    }
}

struct WebKitView: NSViewRepresentable {
    let webView: WKWebView
    @Binding var progress: Double
    @Binding var isLoading: Bool
    var onPageLoaded: (() -> Void)?
    var onVideosExtracted: (([VideoItem]) -> Void)?
    var onNewVideosFound: (([VideoItem]) -> Void)?

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
                self.parent.onNewVideosFound?(videoItems)
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
