//
//  M3U8Models.swift
//  DownloadManager
//
//

import Foundation

// MARK: - EncryptionMethod

/// M3U8 加密方式枚举
public enum EncryptionMethod: String, Codable {
    /// 未加密
    case none
    /// AES-128 加密
    case aes128 = "AES-128"
    /// SAMPLE-AES 加密
    case sampleAes = "SAMPLE-AES"
    /// 未知加密方式
    case unknown
}

// MARK: - MediaSegment

/// M3U8 媒体分片信息
public struct MediaSegment: Codable, Identifiable {
    public let id = UUID()
    /// 分片序列号
    public let sequenceNumber: Int
    /// 分片 URL
    public let url: URL
    /// 分片时长（秒）
    public let duration: TimeInterval
    /// 分片标题
    public let title: String?
    /// 加密方式
    public let encryptionMethod: EncryptionMethod
    /// 加密密钥 URI
    public let encryptionKeyURI: URL?
    /// 初始化向量（IV）
    public let initializationVector: String?
    
    public init(
        sequenceNumber: Int,
        url: URL,
        duration: TimeInterval,
        title: String? = nil,
        encryptionMethod: EncryptionMethod = .none,
        encryptionKeyURI: URL? = nil,
        initializationVector: String? = nil
    ) {
        self.sequenceNumber = sequenceNumber
        self.url = url
        self.duration = duration
        self.title = title
        self.encryptionMethod = encryptionMethod
        self.encryptionKeyURI = encryptionKeyURI
        self.initializationVector = initializationVector
    }
}

// MARK: - VariantStream

/// M3U8 变体流信息（用于多码率支持）
public struct VariantStream: Codable, Identifiable {
    public let id = UUID()
    /// 带宽（bps）
    public let bandwidth: Int
    /// 分辨率
    public let resolution: String?
    /// 编码
    public let codecs: String?
    /// 流 URL
    public let url: URL
    
    public init(
        bandwidth: Int,
        resolution: String? = nil,
        codecs: String? = nil,
        url: URL
    ) {
        self.bandwidth = bandwidth
        self.resolution = resolution
        self.codecs = codecs
        self.url = url
    }
}

// MARK: - M3U8Playlist

/// M3U8 播放列表类型
public enum PlaylistType: String, Codable {
    /// 媒体播放列表
    case media
    /// 主播放列表（变体）
    case master
    /// 未知类型
    case unknown
}

/// M3U8 播放列表
public struct M3U8Playlist: Codable {
    /// 原始 URL
    public let url: URL
    /// 播放列表类型
    public let type: PlaylistType
    /// 变体流列表（仅主播放列表有）
    public let variants: [VariantStream]
    /// 媒体分片列表（仅媒体播放列表有）
    public let segments: [MediaSegment]
    /// 总时长
    public let totalDuration: TimeInterval
    /// 版本
    public let version: Int?
    /// 目标时长
    public let targetDuration: TimeInterval?
    /// 是否为直播流
    public let isLive: Bool
    
    public init(
        url: URL,
        type: PlaylistType = .unknown,
        variants: [VariantStream] = [],
        segments: [MediaSegment] = [],
        totalDuration: TimeInterval = 0,
        version: Int? = nil,
        targetDuration: TimeInterval? = nil,
        isLive: Bool = false
    ) {
        self.url = url
        self.type = type
        self.variants = variants
        self.segments = segments
        self.totalDuration = totalDuration
        self.version = version
        self.targetDuration = targetDuration
        self.isLive = isLive
    }
    
    /// 计算总时长
    public func calculateTotalDuration() -> TimeInterval {
        return segments.reduce(0) { $0 + $1.duration }
    }
}
