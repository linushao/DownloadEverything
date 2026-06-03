//
//  BrowserView.swift
//  DownloadManager
//
//  WebView 视频 URL 嗅探器 - 浏览器视图
//

import Combine
import SwiftUI
import WebKit

#if os(iOS)
    struct BrowserView: View {
        @StateObject private var viewModel = BrowserViewModel()
        @State private var showSnifferPanel: Bool = true

        var body: some View {
            VStack(spacing: 0) {
                // 地址栏和工具栏
                toolbarView

                // WebView 区域
                GeometryReader { geometry in
                    ZStack {
                        BrowserWebView(viewModel: viewModel)
                            .frame(width: geometry.size.width, height: geometry.size.height)

                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                        }
                    }
                }

                // 嗅探结果面板
                if showSnifferPanel {
                    snifferPanelView
                        .frame(height: 200)
                        .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle("浏览器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { withAnimation { showSnifferPanel.toggle() } }) {
                        Image(systemName: showSnifferPanel ? "chevron.down" : "chevron.up")
                    }
                    Button(action: { viewModel.toggleSniffer() }) {
                        Image(
                            systemName: viewModel.isSnifferEnabled
                                ? "antenna.radiowaves.left.and.right"
                                : "antenna.radiowaves.left.and.right.slash")
                    }
                }
            }
        }

        // MARK: - Toolbar View

        private var toolbarView: some View {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // 导航按钮
                    HStack(spacing: 8) {
                        Button(action: { viewModel.goBack() }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!viewModel.canGoBack)

                        Button(action: { viewModel.goForward() }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!viewModel.canGoForward)

                        // 停止/刷新按钮
                        Button(action: {
                            if viewModel.isLoading {
                                viewModel.stopLoading()
                            } else {
                                viewModel.reload()
                            }
                        }) {
                            Image(systemName: viewModel.isLoading ? "xmark" : "arrow.clockwise")
                        }
                    }
                    .font(.system(size: 16))

                    // 地址栏
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("输入网址", text: $viewModel.urlText)
                            .textFieldStyle(.plain)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .onSubmit {
                                viewModel.loadURL()
                            }

                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)

                    // 嗅探开关
                    Toggle(isOn: $viewModel.isSnifferEnabled) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                    .toggleStyle(.button)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))

                // 加载进度条
                if viewModel.loadProgress > 0 && viewModel.loadProgress < 1 {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * viewModel.loadProgress, height: 2)
                    }
                    .frame(height: 2)
                    .background(Color(UIColor.secondarySystemBackground))
                }
            }
        }

        // MARK: - Sniffer Panel View

        private var snifferPanelView: some View {
            VStack(spacing: 0) {
                // 面板头部
                HStack {
                    Text("嗅探结果")
                        .font(.headline)

                    Spacer()

                    Text("\(viewModel.snifferResults.count) 个视频")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.secondarySystemBackground))

                Divider()

                // 结果列表
                if viewModel.snifferResults.isEmpty {
                    VStack {
                        Spacer()
                        Text("暂无嗅探结果")
                            .foregroundColor(.secondary)
                        Text("浏览网页时自动检测视频链接")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(viewModel.snifferResults) { result in
                        SnifferResultRow(result: result, viewModel: viewModel)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(UIColor.systemBackground))
        }
    }

    // MARK: - Sniffer Result Row

    struct SnifferResultRow: View {
        let result: SnifferResult
        @ObservedObject var viewModel: BrowserViewModel

        var body: some View {
            HStack(spacing: 12) {
                // 视频图标
                Image(systemName: "video.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)

                // URL 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.fileName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)

                    Text(result.url.absoluteString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // 格式标签
                Text(result.format.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)

                // 操作按钮
                Menu {
                    Button("复制链接") {
                        viewModel.copyURL(result.url)
                    }
                    Button("添加到下载") {
                        viewModel.addToDownload(result.url)
                    }
                    Button("预览") {
                        viewModel.previewVideo(result.url)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Browser WebView (iOS)

    struct BrowserWebView: UIViewRepresentable {
        @ObservedObject var viewModel: BrowserViewModel

        func makeUIView(context: Context) -> WKWebView {
            let configuration = WKWebViewConfiguration()
            configuration.allowsInlineMediaPlayback = true

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = context.coordinator
            webView.allowsBackForwardNavigationGestures = true

            // 设置 User-Agent
            webView.customUserAgent =
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

            viewModel.webView = webView
            viewModel.configureWebView(webView)
            return webView
        }

        func updateUIView(_ uiView: WKWebView, context: Context) {
            // URL 更新由 ViewModel 处理
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(viewModel: viewModel)
        }

        class Coordinator: NSObject, WKNavigationDelegate {
            let viewModel: BrowserViewModel
            private var cancellables = Set<AnyCancellable>()
            private weak var webView: WKWebView?

            init(viewModel: BrowserViewModel) {
                self.viewModel = viewModel
            }

            func setupProgressObservation(for webView: WKWebView) {
                self.webView = webView
                webView.publisher(for: \.estimatedProgress)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] progress in
                        self?.viewModel.loadProgress = progress
                    }
                    .store(in: &cancellables)
            }

            func webView(
                _ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!
            ) {
                if self.webView !== webView {
                    setupProgressObservation(for: webView)
                }
                DispatchQueue.main.async {
                    self.viewModel.isLoading = true
                    self.viewModel.loadProgress = 0
                }
            }

            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                DispatchQueue.main.async {
                    self.viewModel.isLoading = false
                    self.viewModel.canGoBack = webView.canGoBack
                    self.viewModel.canGoForward = webView.canGoForward
                    self.viewModel.currentURL = webView.url
                    self.viewModel.loadProgress = 1.0
                }
            }

            func webView(
                _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
            ) {
                DispatchQueue.main.async {
                    self.viewModel.isLoading = false
                    self.viewModel.loadProgress = 0
                }
            }

            func webView(
                _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
            ) {
                // URL 验证和视频嗅探
                if let requestURL = navigationAction.request.url {
                    // 更新地址栏（仅针对主框架导航）
                    if navigationAction.targetFrame == nil
                        || navigationAction.targetFrame?.isMainFrame == true
                    {
                        DispatchQueue.main.async {
                            self.viewModel.urlText = requestURL.absoluteString
                        }
                    }

                    // 嗅探视频 URL
                    viewModel.checkAndAddSnifferResult(url: requestURL)
                }

                decisionHandler(.allow)
            }
        }
    }

#elseif os(macOS)
    // macOS Browser View
    struct BrowserView: View {
        @StateObject private var viewModel = BrowserViewModel()
        @State private var showSnifferPanel: Bool = true

        var body: some View {
            VStack(spacing: 0) {
                toolbarView

                GeometryReader { geometry in
                    ZStack {
                        BrowserWebView(viewModel: viewModel)
                            .frame(width: geometry.size.width, height: geometry.size.height)

                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                        }
                    }
                }

                if showSnifferPanel {
                    snifferPanelView
                        .frame(height: 200)
                        .transition(.move(edge: .bottom))
                }
            }
        }

        private var toolbarView: some View {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Button(action: { viewModel.goBack() }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!viewModel.canGoBack)

                        Button(action: { viewModel.goForward() }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!viewModel.canGoForward)

                        // 停止/刷新按钮
                        Button(action: {
                            if viewModel.isLoading {
                                viewModel.stopLoading()
                            } else {
                                viewModel.reload()
                            }
                        }) {
                            Image(systemName: viewModel.isLoading ? "xmark" : "arrow.clockwise")
                        }
                    }
                    .font(.system(size: 16))

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("输入网址", text: $viewModel.urlText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .onSubmit {
                                viewModel.loadURL()
                            }

                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)

                    Toggle(isOn: $viewModel.isSnifferEnabled) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                    .toggleStyle(.button)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))

                // 加载进度条
                if viewModel.loadProgress > 0 && viewModel.loadProgress < 1 {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * viewModel.loadProgress, height: 2)
                    }
                    .frame(height: 2)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
        }

        private var snifferPanelView: some View {
            VStack(spacing: 0) {
                HStack {
                    Text("嗅探结果")
                        .font(.headline)

                    Spacer()

                    Text("\(viewModel.snifferResults.count) 个视频")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                if viewModel.snifferResults.isEmpty {
                    VStack {
                        Spacer()
                        Text("暂无嗅探结果")
                            .foregroundColor(.secondary)
                        Text("浏览网页时自动检测视频链接")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(viewModel.snifferResults) { result in
                        SnifferResultRow(result: result, viewModel: viewModel)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    // MARK: - Sniffer Result Row (macOS)

    struct SnifferResultRow: View {
        let result: SnifferResult
        @ObservedObject var viewModel: BrowserViewModel

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "video.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.fileName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)

                    Text(result.url.absoluteString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(result.format.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)

                Menu {
                    Button("复制链接") {
                        viewModel.copyURL(result.url)
                    }
                    Button("添加到下载") {
                        viewModel.addToDownload(result.url)
                    }
                    Button("预览") {
                        viewModel.previewVideo(result.url)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Browser WebView (macOS)

    struct BrowserWebView: NSViewRepresentable {
        @ObservedObject var viewModel: BrowserViewModel

        func makeNSView(context: Context) -> WKWebView {
            let configuration = WKWebViewConfiguration()

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = context.coordinator
            webView.allowsBackForwardNavigationGestures = true

            viewModel.webView = webView
            viewModel.configureWebView(webView)
            return webView
        }

        func updateNSView(_ nsView: WKWebView, context: Context) {
            // URL 更新由 ViewModel 处理
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(viewModel: viewModel)
        }

        class Coordinator: NSObject, WKNavigationDelegate {
            let viewModel: BrowserViewModel
            private var cancellables = Set<AnyCancellable>()
            private weak var webView: WKWebView?

            init(viewModel: BrowserViewModel) {
                self.viewModel = viewModel
            }

            func setupProgressObservation(for webView: WKWebView) {
                self.webView = webView
                webView.publisher(for: \.estimatedProgress)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] progress in
                        self?.viewModel.loadProgress = progress
                    }
                    .store(in: &cancellables)
            }

            func webView(
                _ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!
            ) {
                if self.webView !== webView {
                    setupProgressObservation(for: webView)
                }
                DispatchQueue.main.async {
                    self.viewModel.isLoading = true
                    self.viewModel.loadProgress = 0
                }
            }

            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                DispatchQueue.main.async {
                    self.viewModel.isLoading = false
                    self.viewModel.canGoBack = webView.canGoBack
                    self.viewModel.canGoForward = webView.canGoForward
                    self.viewModel.currentURL = webView.url
                    self.viewModel.loadProgress = 1.0
                }
            }

            func webView(
                _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
            ) {
                DispatchQueue.main.async {
                    self.viewModel.isLoading = false
                    self.viewModel.loadProgress = 0
                }
            }

            func webView(
                _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
            ) {
                // URL 验证和视频嗅探
                if let requestURL = navigationAction.request.url {
                    // 更新地址栏（仅针对主框架导航）
                    if navigationAction.targetFrame == nil
                        || navigationAction.targetFrame?.isMainFrame == true
                    {
                        DispatchQueue.main.async {
                            self.viewModel.urlText = requestURL.absoluteString
                        }
                    }

                    // 嗅探视频 URL
                    viewModel.checkAndAddSnifferResult(url: requestURL)
                }

                decisionHandler(.allow)
            }
        }
    }
#endif

// MARK: - Preview

#if DEBUG
    struct BrowserView_Previews: PreviewProvider {
        static var previews: some View {
            BrowserView()
        }
    }
#endif
