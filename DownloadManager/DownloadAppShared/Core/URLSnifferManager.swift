//
//  URLSnifferManager.swift
//  DownloadManager
//
//  WebView 视频 URL 嗅探管理器
//

import Combine
import Foundation
import WebKit

// MARK: - Video Format

enum VideoFormat: String, CaseIterable {
    case mp4
    case m3u8
    case webm
    case flv
    case mov
    case avi
    case mkv
    case ts
    case wmv
    case m4v

    var fileExtension: String {
        rawValue
    }

    var mimeTypes: [String] {
        switch self {
        case .mp4:
            return ["video/mp4", "application/mp4"]
        case .m3u8:
            return ["application/vnd.apple.mpegurl", "audio/mpegurl", "application/x-mpegurl"]
        case .webm:
            return ["video/webm"]
        case .flv:
            return ["video/x-flv"]
        case .mov:
            return ["video/quicktime"]
        case .avi:
            return ["video/x-msvideo"]
        case .mkv:
            return ["video/x-matroska"]
        case .ts:
            return ["video/MP2T", "video/mp2t"]
        case .wmv:
            return ["video/x-ms-wmv"]
        case .m4v:
            return ["video/x-m4v"]
        }
    }
}

// MARK: - Sniffer Result

struct SniffedVideo: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let format: VideoFormat
    let fileName: String
    let fileSize: Int64?
    let sniffedAt: Date

    var formattedFileSize: String {
        guard let size = fileSize else { return "未知大小" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    static func == (lhs: SniffedVideo, rhs: SniffedVideo) -> Bool {
        lhs.url == rhs.url
    }
}

// MARK: - URL Sniffer Manager

@MainActor
final class URLSnifferManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = URLSnifferManager()

    // MARK: - Published Properties

    @Published private(set) var sniffedVideos: [SniffedVideo] = []
    @Published var isEnabled: Bool = true

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var interceptedURLs = Set<String>()
    private let schemeHandler = VideoSchemeHandler()

    // MARK: - Initialization

    private override init() {
        super.init()
        setupSchemeHandler()
    }

    // MARK: - Public Methods

    func configureWebView(_ webView: WKWebView) {
        // 设置配置
        let config = webView.configuration

        // 注册自定义 scheme 处理（用于 https/http 拦截需要额外处理）
        // 注意：WKWebView 默认不允许拦截 http/https，这里我们通过其他方式处理

        // 设置 UserContentController 用于监听
        let userContentController = config.userContentController
        userContentController.removeAllUserScripts()

        // 注入 JS 监听网络请求（辅助方案）
        injectNetworkListenerScript(into: userContentController)
    }

    func checkAndSniffURL(_ url: URL, completion: ((SniffedVideo?) -> Void)? = nil) {
        guard isEnabled else {
            completion?(nil)
            return
        }

        // 去重检查
        guard !interceptedURLs.contains(url.absoluteString) else {
            completion?(nil)
            return
        }

        // 首先通过扩展名检测
        if let format = detectFormatByExtension(url) {
            Task {
                let video = await createSniffedVideo(url: url, format: format)
                addSniffedVideo(video)
                completion?(video)
            }
            return
        }

        // 通过 HEAD 请求检测 Content-Type
        Task {
            if let (format, contentLength) = await detectFormatByContentType(url) {
                let video = await createSniffedVideo(
                    url: url, format: format, fileSize: contentLength)
                addSniffedVideo(video)
                completion?(video)
            } else {
                completion?(nil)
            }
        }
    }

    func clearResults() {
        sniffedVideos.removeAll()
        interceptedURLs.removeAll()
    }

    // MARK: - Private Methods

    private func setupSchemeHandler() {
        schemeHandler.onVideoDetected = { [weak self] video in
            self?.addSniffedVideo(video)
        }
    }

    private func injectNetworkListenerScript(into userContentController: WKUserContentController) {
        // 简单的 JS 脚本用于监听 fetch 和 XMLHttpRequest
        let scriptSource = """
            (function() {
                // 监听 fetch
                const originalFetch = window.fetch;
                window.fetch = function(...args) {
                    const url = args[0];
                    if (typeof url === 'string') {
                        window.webkit.messageHandlers.videoSniffer.postMessage({type: 'fetch', url: url});
                    } else if (url instanceof URL) {
                        window.webkit.messageHandlers.videoSniffer.postMessage({type: 'fetch', url: url.href});
                    } else if (url instanceof Request) {
                        window.webkit.messageHandlers.videoSniffer.postMessage({type: 'fetch', url: url.url});
                    }
                    return originalFetch.apply(this, args);
                };

                // 监听 XMLHttpRequest
                const originalOpen = XMLHttpRequest.prototype.open;
                XMLHttpRequest.prototype.open = function(method, url, ...args) {
                    window.webkit.messageHandlers.videoSniffer.postMessage({type: 'xhr', url: url});
                    return originalOpen.apply(this, [method, url, ...args]);
                };
            })();
            """

        let script = WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        userContentController.addUserScript(script)
        userContentController.add(self, name: "videoSniffer")
    }

    private func detectFormatByExtension(_ url: URL) -> VideoFormat? {
        let urlString = url.absoluteString.lowercased()

        for format in VideoFormat.allCases {
            if urlString.contains(".\(format.fileExtension)")
                || urlString.contains("format=\(format.fileExtension)")
                || urlString.contains("ext=\(format.fileExtension)")
            {
                return format
            }
        }

        return nil
    }

    private func detectFormatByContentType(_ url: URL) async -> (VideoFormat, Int64?)? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }

            // 获取 Content-Type
            if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String {
                for format in VideoFormat.allCases {
                    for mimeType in format.mimeTypes {
                        if contentType.lowercased().contains(mimeType.lowercased()) {
                            // 获取 Content-Length
                            var contentLength: Int64?
                            if let lengthString = httpResponse.allHeaderFields["Content-Length"]
                                as? String,
                                let length = Int64(lengthString)
                            {
                                contentLength = length
                            }
                            return (format, contentLength)
                        }
                    }
                }
            }
        } catch {
            // HEAD 请求失败，忽略
        }

        return nil
    }

    private func createSniffedVideo(url: URL, format: VideoFormat, fileSize: Int64? = nil) async
        -> SniffedVideo
    {
        let fileName =
            url.lastPathComponent.isEmpty ? "video.\(format.fileExtension)" : url.lastPathComponent

        // 如果没有提供文件大小，尝试通过 HEAD 请求获取
        var finalFileSize = fileSize
        if finalFileSize == nil {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 3.0

            if let (_, response) = try? await URLSession.shared.data(for: request),
                let httpResponse = response as? HTTPURLResponse,
                let lengthString = httpResponse.allHeaderFields["Content-Length"] as? String,
                let length = Int64(lengthString)
            {
                finalFileSize = length
            }
        }

        return SniffedVideo(
            url: url,
            format: format,
            fileName: fileName,
            fileSize: finalFileSize,
            sniffedAt: Date()
        )
    }

    private func createSniffedVideo(url: URL, format: VideoFormat, fileSize: Int64?) -> SniffedVideo
    {
        let fileName =
            url.lastPathComponent.isEmpty ? "video.\(format.fileExtension)" : url.lastPathComponent

        return SniffedVideo(
            url: url,
            format: format,
            fileName: fileName,
            fileSize: fileSize,
            sniffedAt: Date()
        )
    }

    private func addSniffedVideo(_ video: SniffedVideo) {
        guard !interceptedURLs.contains(video.url.absoluteString) else { return }

        interceptedURLs.insert(video.url.absoluteString)

        if !sniffedVideos.contains(video) {
            sniffedVideos.insert(video, at: 0)
        }
    }
}

// MARK: - WKScriptMessageHandler

extension URLSnifferManager: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "videoSniffer" else { return }

        if let body = message.body as? [String: Any],
            let urlString = body["url"] as? String,
            let url = URL(string: urlString)
        {
            checkAndSniffURL(url)
        }
    }
}

// MARK: - Video Scheme Handler

final class VideoSchemeHandler: NSObject, WKURLSchemeHandler {

    var onVideoDetected: ((SniffedVideo) -> Void)?

    private let taskMap = NSMapTable<WKURLSchemeTask, URLSessionDataTask>.weakToStrongObjects()

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "URLSniffer", code: -1))
            return
        }

        // 创建数据任务
        let task = URLSession.shared.dataTask(with: urlSchemeTask.request) {
            [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                urlSchemeTask.didFailWithError(error)
                self.taskMap.removeObject(forKey: urlSchemeTask)
                return
            }

            if let response = response {
                urlSchemeTask.didReceive(response)
            }

            if let data = data {
                urlSchemeTask.didReceive(data)
            }

            urlSchemeTask.didFinish()
            self.taskMap.removeObject(forKey: urlSchemeTask)

            // 检查是否是视频
            self.checkAndNotifyVideo(url: url, response: response)
        }

        taskMap.setObject(task, forKey: urlSchemeTask)
        task.resume()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        taskMap.object(forKey: urlSchemeTask)?.cancel()
        taskMap.removeObject(forKey: urlSchemeTask)
    }

    private func checkAndNotifyVideo(url: URL, response: URLResponse?) {
        // 通过扩展名检测
        for format in VideoFormat.allCases {
            if url.absoluteString.lowercased().contains(".\(format.fileExtension)") {
                let fileName =
                    url.lastPathComponent.isEmpty
                    ? "video.\(format.fileExtension)" : url.lastPathComponent
                let contentLength = (response as? HTTPURLResponse)?.expectedContentLength

                let fileSize: Int64? =
                    if let length = contentLength, length > 0 {
                        length
                    } else {
                        nil
                    }

                let video = SniffedVideo(
                    url: url,
                    format: format,
                    fileName: fileName,
                    fileSize: fileSize,
                    sniffedAt: Date()
                )

                onVideoDetected?(video)
                return
            }
        }

        // 通过 Content-Type 检测
        if let httpResponse = response as? HTTPURLResponse,
            let contentType = httpResponse.allHeaderFields["Content-Type"] as? String
        {
            for format in VideoFormat.allCases {
                for mimeType in format.mimeTypes {
                    if contentType.lowercased().contains(mimeType.lowercased()) {
                        let fileName =
                            url.lastPathComponent.isEmpty
                            ? "video.\(format.fileExtension)" : url.lastPathComponent
                        let contentLength = httpResponse.expectedContentLength

                        let fileSize: Int64? =
                            if contentLength > 0 {
                                contentLength
                            } else {
                                nil
                            }

                        let video = SniffedVideo(
                            url: url,
                            format: format,
                            fileName: fileName,
                            fileSize: fileSize,
                            sniffedAt: Date()
                        )

                        onVideoDetected?(video)
                        return
                    }
                }
            }
        }
    }
}
