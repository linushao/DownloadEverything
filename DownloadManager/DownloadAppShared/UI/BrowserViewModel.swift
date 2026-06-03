//
//  BrowserViewModel.swift
//  DownloadManager
//
//  WebView 视频 URL 嗅探器 - 浏览器视图模型
//

import Combine
import Foundation
import SwiftUI
import WebKit

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

// MARK: - Sniffer Result Model (保持向后兼容)

struct SnifferResult: Identifiable {
    let id = UUID()
    let url: URL
    let format: String
    let fileName: String
    let fileSize: Int64?

    var formattedFileSize: String {
        guard let size = fileSize else { return "未知大小" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    init(from sniffedVideo: SniffedVideo) {
        self.url = sniffedVideo.url
        self.format = sniffedVideo.format.rawValue
        self.fileName = sniffedVideo.fileName
        self.fileSize = sniffedVideo.fileSize
    }
}

// MARK: - Browser ViewModel

@MainActor
class BrowserViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var urlText: String = ""
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var currentURL: URL?
    @Published var isSnifferEnabled: Bool = true
    @Published var snifferResults: [SnifferResult] = []
    @Published var loadProgress: Double = 0

    // MARK: - WebView Reference

    weak var webView: WKWebView?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let snifferManager = URLSnifferManager.shared

    // MARK: - Initialization

    init() {
        setupSnifferObserver()
    }

    // MARK: - Navigation Methods

    func loadURL() {
        guard let url = buildURL(from: urlText) else { return }
        currentURL = url
        webView?.load(URLRequest(url: url))
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }

    func stopLoading() {
        webView?.stopLoading()
    }

    func toggleSniffer() {
        isSnifferEnabled.toggle()
        snifferManager.isEnabled = isSnifferEnabled
        if !isSnifferEnabled {
            snifferManager.clearResults()
        }
    }

    // MARK: - URL Operations

    func copyURL(_ url: URL) {
        #if os(iOS)
            UIPasteboard.general.string = url.absoluteString
        #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
        #endif
    }

    func addToDownload(_ url: URL) {
        // TODO: 集成 DownloadManager 的下载功能
        print("添加下载: \(url.absoluteString)")
    }

    func previewVideo(_ url: URL) {
        // TODO: 实现视频预览功能
        print("预览视频: \(url.absoluteString)")
    }

    // MARK: - Sniffer Methods

    private func setupSnifferObserver() {
        // 监听 URLSnifferManager 的嗅探结果
        snifferManager.$sniffedVideos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] videos in
                self?.snifferResults = videos.map { SnifferResult(from: $0) }
            }
            .store(in: &cancellables)

        // 同步嗅探开关状态
        snifferManager.isEnabled = isSnifferEnabled
    }

    func checkAndAddSnifferResult(url: URL) {
        guard isSnifferEnabled else { return }
        snifferManager.checkAndSniffURL(url)
    }

    func clearSnifferResults() {
        snifferManager.clearResults()
    }

    func configureWebView(_ webView: WKWebView) {
        snifferManager.configureWebView(webView)
    }

    // MARK: - Private Methods

    private func buildURL(from string: String) -> URL? {
        var urlString = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // 如果没有协议，添加 https://
        if !urlString.contains("://") {
            urlString = "https://" + urlString
        }

        // 验证 URL 格式
        if let url = URL(string: urlString), url.scheme != nil {
            return url
        }

        // 尝试作为搜索引擎查询
        let encodedQuery =
            urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
        if let searchURL = URL(string: "https://www.google.com/search?q=\(encodedQuery)") {
            return searchURL
        }

        return nil
    }
}
