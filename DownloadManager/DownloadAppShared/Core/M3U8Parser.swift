//
//  M3U8Parser.swift
//  DownloadManager
//
//

import Foundation

// MARK: - M3U8ParserError

public enum M3U8ParserError: LocalizedError {
    case invalidURL
    case invalidFormat
    case networkError(Error)
    case emptyPlaylist
    case parsingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidFormat:
            return "无效的 M3U8 格式"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .emptyPlaylist:
            return "播放列表为空"
        case .parsingFailed(let message):
            return "解析失败: \(message)"
        }
    }
}

// MARK: - M3U8Parser

/// M3U8 播放列表解析器
public final class M3U8Parser {
    
    // MARK: - Properties
    
    private let networkService: NetworkService
    
    // MARK: - Initialization
    
    public init(networkService: NetworkService = .shared) {
        self.networkService = networkService
    }
    
    // MARK: - Public Methods
    
    /// 异步解析 M3U8 URL
    /// - Parameter url: M3U8 播放列表 URL
    /// - Returns: 解析后的 M3U8Playlist
    public func parse(url: URL) async throws -> M3U8Playlist {
        let data = try await networkService.get(url: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw M3U8ParserError.invalidFormat
        }
        return try parse(content: content, baseURL: url)
    }
    
    /// 解析 M3U8 内容字符串
    /// - Parameters:
    ///   - content: M3U8 内容
    ///   - baseURL: 基础 URL（用于补全相对路径）
    /// - Returns: 解析后的 M3U8Playlist
    public func parse(content: String, baseURL: URL) throws -> M3U8Playlist {
        let lines = content.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            throw M3U8ParserError.emptyPlaylist
        }
        
        guard lines.first?.hasPrefix("#EXTM3U") == true else {
            throw M3U8ParserError.invalidFormat
        }
        
        var variants: [VariantStream] = []
        var segments: [MediaSegment] = []
        var currentEncryptionMethod: EncryptionMethod = .none
        var currentEncryptionKeyURI: URL?
        var currentIV: String?
        var version: Int?
        var targetDuration: TimeInterval?
        var sequenceNumber = 0
        var isLive = false
        
        var i = 1
        while i < lines.count {
            let line = lines[i]
            
            if line.hasPrefix("#") {
                try parseTag(line: line, variants: &variants, segments: &segments, encryptionMethod: &currentEncryptionMethod, encryptionKeyURI: &currentEncryptionKeyURI, initializationVector: &currentIV, version: &version, targetDuration: &targetDuration, sequenceNumber: &sequenceNumber, isLive: &isLive, baseURL: baseURL, lines: lines, currentIndex: &i)
            } else if !line.hasPrefix("#") && !line.isEmpty {
                // 这是一个 URL
                if !variants.isEmpty {
                    // 这是变体流 URL
                    // 已经在 #EXT-X-STREAM-INF 标签中处理了
                } else {
                    // 这是分片 URL
                    if let url = resolveURL(line, baseURL: baseURL) {
                        let segment = MediaSegment(
                            sequenceNumber: sequenceNumber,
                            url: url,
                            duration: 0,
                            title: nil,
                            encryptionMethod: currentEncryptionMethod,
                            encryptionKeyURI: currentEncryptionKeyURI,
                            initializationVector: currentIV
                        )
                        segments.append(segment)
                        sequenceNumber += 1
                    }
                }
            }
            
            i += 1
        }
        
        // 计算总时长
        let totalDuration = segments.reduce(0) { $0 + $1.duration }
        
        // 判断播放列表类型
        let type: PlaylistType = !variants.isEmpty ? .master : (!segments.isEmpty ? .media : .unknown)
        
        return M3U8Playlist(
            url: baseURL,
            type: type,
            variants: variants,
            segments: segments,
            totalDuration: totalDuration,
            version: version,
            targetDuration: targetDuration,
            isLive: isLive
        )
    }
    
    /// 检查 URL 是否为有效的 M3U8
    /// - Parameter url: 要检查的 URL
    /// - Returns: 是否有效
    public func isValidM3U8(url: URL) async -> Bool {
        do {
            _ = try await parse(url: url)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func parseTag(line: String, variants: inout [VariantStream], segments: inout [MediaSegment], encryptionMethod: inout EncryptionMethod, encryptionKeyURI: inout URL?, initializationVector: inout String?, version: inout Int?, targetDuration: inout TimeInterval?, sequenceNumber: inout Int, isLive: inout Bool, baseURL: URL, lines: [String], currentIndex: inout Int) throws {
        
        if line.hasPrefix("#EXT-X-VERSION:") {
            let value = String(line.dropFirst("#EXT-X-VERSION:".count))
            version = Int(value)
            
        } else if line.hasPrefix("#EXT-X-TARGETDURATION:") {
            let value = String(line.dropFirst("#EXT-X-TARGETDURATION:".count))
            if let duration = TimeInterval(value) {
                targetDuration = duration
            }
            
        } else if line.hasPrefix("#EXT-X-MEDIA-SEQUENCE:") {
            let value = String(line.dropFirst("#EXT-X-MEDIA-SEQUENCE:".count))
            sequenceNumber = Int(value) ?? 0
            
        } else if line.hasPrefix("#EXT-X-ENDLIST") {
            isLive = false
            
        } else if line.hasPrefix("#EXT-X-KEY:") {
            let keyContent = String(line.dropFirst("#EXT-X-KEY:".count))
            let attributes = parseAttributes(keyContent)
            
            if let method = attributes["METHOD"] {
                encryptionMethod = EncryptionMethod(rawValue: method) ?? .unknown
            }
            
            if let uri = attributes["URI"]?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) {
                encryptionKeyURI = resolveURL(uri, baseURL: baseURL)
            }
            
            if let iv = attributes["IV"] {
                initializationVector = iv
            }
            
        } else if line.hasPrefix("#EXTINF:") {
            let infContent = String(line.dropFirst("#EXTINF:".count))
            let parts = infContent.components(separatedBy: ",")
            var duration: TimeInterval = 0
            var title: String?
            
            if let firstPart = parts.first {
                duration = TimeInterval(firstPart) ?? 0
            }
            
            if parts.count > 1 {
                title = parts[1].trimmingCharacters(in: .whitespaces)
            }
            
            // 下一行应该是分片 URL
            currentIndex += 1
            if currentIndex < lines.count {
                let urlLine = lines[currentIndex]
                if let url = resolveURL(urlLine, baseURL: baseURL) {
                    let segment = MediaSegment(
                        sequenceNumber: sequenceNumber,
                        url: url,
                        duration: duration,
                        title: title,
                        encryptionMethod: encryptionMethod,
                        encryptionKeyURI: encryptionKeyURI,
                        initializationVector: initializationVector
                    )
                    segments.append(segment)
                    sequenceNumber += 1
                }
            }
            
        } else if line.hasPrefix("#EXT-X-STREAM-INF:") {
            let streamContent = String(line.dropFirst("#EXT-X-STREAM-INF:".count))
            let attributes = parseAttributes(streamContent)
            
            var bandwidth = 0
            var resolution: String?
            var codecs: String?
            
            if let bandwidthStr = attributes["BANDWIDTH"], let bw = Int(bandwidthStr) {
                bandwidth = bw
            }
            
            resolution = attributes["RESOLUTION"]
            codecs = attributes["CODECS"]
            
            // 下一行是变体 URL
            currentIndex += 1
            if currentIndex < lines.count {
                let urlLine = lines[currentIndex]
                if let url = resolveURL(urlLine, baseURL: baseURL) {
                    let variant = VariantStream(
                        bandwidth: bandwidth,
                        resolution: resolution,
                        codecs: codecs,
                        url: url
                    )
                    variants.append(variant)
                }
            }
        }
    }
    
    private func parseAttributes(_ content: String) -> [String: String] {
        var attributes: [String: String] = [:]
        var currentKey = ""
        var currentValue = ""
        var inQuotes = false
        var i = content.startIndex
        
        while i < content.endIndex {
            let char = content[i]
            
            if char == "\"" {
                inQuotes.toggle()
                if !inQuotes {
                    // 结束一个带引号的值
                    attributes[currentKey] = currentValue
                    currentKey = ""
                    currentValue = ""
                }
            } else if char == "=" && !inQuotes && !currentKey.isEmpty {
                // 开始一个值
                continue
            } else if char == "," && !inQuotes && !currentKey.isEmpty {
                // 结束一个属性
                if !currentValue.isEmpty {
                    attributes[currentKey] = currentValue
                }
                currentKey = ""
                currentValue = ""
            } else {
                if currentKey.isEmpty {
                    currentKey.append(char)
                } else if inQuotes || char != "=" {
                    currentValue.append(char)
                }
            }
            
            i = content.index(after: i)
        }
        
        // 处理最后一个属性
        if !currentKey.isEmpty {
            attributes[currentKey] = currentValue
        }
        
        return attributes
    }
    
    private func resolveURL(_ path: String, baseURL: URL) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        } else {
            return URL(string: path, relativeTo: baseURL)?.absoluteURL
        }
    }
}
