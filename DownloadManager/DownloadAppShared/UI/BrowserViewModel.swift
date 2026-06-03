//
//  BrowserViewModel.swift
//  DownloadManager
//
//  WebView 视频 URL 嗅探器 - 浏览器视图模型
//

import Foundation
import WebKit
import Combine
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Sniffer Result Model

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

    // MARK: - WebView Reference

    weak var webView: WKWebView?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var interceptedURLs = Set<String>()

    // MARK: - Supported Video Formats

    private let supportedFormats = ["mp4", "m3u8", "webm", "flv", "mov", "avi", "mkv"]

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
        if !isSnifferEnabled {
            snifferResults.removeAll()
            interceptedURLs.removeAll()
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
        // 监听 WebView 的 URL 变化来嗅探视频
    }

    func checkAndAddSnifferResult(url: URL) {
        guard isSnifferEnabled else { return }

        // 检查是否是视频 URL
        let urlString = url.absoluteString.lowercased()

        for format in supportedFormats {
            if urlString.contains(".\(format)") || urlString.contains("format=\(format)") {
                addSnifferResult(url: url, format: format)
                return
            }
        }
    }

    private func addSnifferResult(url: URL, format: String) {
        // 去重检查
        guard !interceptedURLs.contains(url.absoluteString) else { return }
        interceptedURLs.insert(url.absoluteString)

        let fileName = url.lastPathComponent.isEmpty ? "video.\(format)" : url.lastPathComponent

        let result = SnifferResult(
            url: url,
            format: format,
            fileName: fileName,
            fileSize: nil
        )

        snifferResults.insert(result, at: 0)
    }

    func clearSnifferResults() {
        snifferResults.removeAll()
        interceptedURLs.removeAll()
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
        let encodedQuery = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
        if let searchURL = URL(string: "https://www.google.com/search?q=\(encodedQuery)") {
            return searchURL
        }

        return nil
    }
}
