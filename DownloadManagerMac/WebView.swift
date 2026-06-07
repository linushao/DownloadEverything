import SwiftUI
import WebKit

struct WebView: View {
    @State private var urlString = "https://www.apple.com"
    @State private var progress: Double = 0.0
    @State private var isLoading = false
    
    @EnvironmentObject var settingsManager: SettingsManager
    
    private let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        return WKWebView(frame: .zero, configuration: configuration)
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // URL输入栏
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
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // 进度条
            if isLoading || progress > 0 {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(height: 2)
                    .animation(.easeInOut, value: progress)
            }
            
            // Web内容区域
            WebKitView(webView: webView, progress: $progress, isLoading: $isLoading)
                .edgesIgnoringSafeArea(.bottom)
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
}

struct WebKitView: NSViewRepresentable {
    let webView: WKWebView
    @Binding var progress: Double
    @Binding var isLoading: Bool
    
    func makeNSView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: WebKitView
        
        init(_ parent: WebKitView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
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
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.progress = 0.0
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.progress = 0.0
        }
    }
}

#Preview {
    WebView()
        .frame(height: 600)
}
