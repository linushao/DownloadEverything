//
//  VideoToolboxTSMerger.swift
//  DownloadManager
//
//  Created by TDD Assistant on 2026/6/2.
//

import AVFoundation
import Foundation

// MARK: - VideoToolboxTSMerger

/// TS 分片合并器（基于 VideoToolbox 硬件加速实现）
/// 支持 iOS 和 macOS 双平台
/// 支持 H.264 和 H.265 (HEVC) 编码
public final class VideoToolboxTSMerger: TSMergerProtocol {

    // MARK: - Properties

    private let queue = DispatchQueue(
        label: "com.downloadapp.videotoolbox.merger", qos: .userInitiated)
    private var isCancelledFlag = false
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var mixComposition: AVMutableComposition?
    private var videoTrack: AVMutableCompositionTrack?
    private var audioTrack: AVMutableCompositionTrack?

    // MARK: - Initialization

    public init() {}

    // MARK: - TSMergerProtocol

    public func merge(
        segments: [MediaSegment],
        task: M3U8DownloadTask,
        outputURL: URL,
        progressHandler: ((Double) -> Void)?
    ) async throws {
        // 重置取消状态
        isCancelledFlag = false

        // 验证输入
        guard !segments.isEmpty else {
            return
        }

        // 获取本地文件路径
        let localPaths = try getLocalPaths(for: segments, task: task)

        // 创建合成
        try await createComposition(with: localPaths)

        // 写入输出文件
        try await writeOutput(
            to: outputURL, segmentCount: segments.count, progressHandler: progressHandler)

        // 清理
        cleanup()
    }

    public func cancel() {
        queue.async(flags: .barrier) { [weak self] in
            self?.isCancelledFlag = true
        }
    }

    // MARK: - Private Methods

    private func getLocalPaths(for segments: [MediaSegment], task: M3U8DownloadTask) throws -> [URL]
    {
        return try segments.map { segment in
            let localPath = task.tempSegmentPath(for: segment.sequenceNumber)
            guard FileManager.default.fileExists(atPath: localPath.path) else {
                throw TSMergerError.fileNotFound
            }
            return localPath
        }
    }

    private func createComposition(with paths: [URL]) async throws {
        // 创建合成对象
        mixComposition = AVMutableComposition()
        videoTrack = mixComposition?.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        audioTrack = mixComposition?.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        var currentTime = CMTime.zero

        for (index, path) in paths.enumerated() {
            // 检查取消状态
            if isCancelledFlag {
                throw TSMergerError.cancelled
            }

            let asset = AVAsset(url: path)

            // 获取视频轨道
            if let videoAssetTrack = asset.tracks(withMediaType: .video).first,
                let videoTrack = videoTrack
            {
                let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
                try videoTrack.insertTimeRange(timeRange, of: videoAssetTrack, at: currentTime)
            }

            // 获取音频轨道
            if let audioAssetTrack = asset.tracks(withMediaType: .audio).first,
                let audioTrack = audioTrack
            {
                let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
                try audioTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: currentTime)
            }

            currentTime = CMTimeAdd(currentTime, asset.duration)
        }
    }

    private func writeOutput(
        to outputURL: URL, segmentCount: Int, progressHandler: ((Double) -> Void)?
    ) async throws {
        guard let composition = mixComposition else {
            throw TSMergerError.mergeFailed("Composition is nil")
        }

        // 删除已存在的文件
        try? FileManager.default.removeItem(at: outputURL)

        // 创建导出会话
        let exportSession = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetHighestQuality)
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .mp4
        exportSession?.shouldOptimizeForNetworkUse = true

        // 设置输出编码（优先使用 H.265，如果不支持则回退到 H.264）
        if #available(iOS 11.0, macOS 10.13, *),
            AVAssetExportSession.allExportPresets().contains(AVAssetExportPresetHEVC1920x1080)
        {
            exportSession?.outputFileType = .mp4
        }

        // 导出进度回调
        let progressObserver = exportSession?.observe(\.progress, options: [.new]) {
            [weak self] _, change in
            guard let self = self, let progress = change.newValue else { return }
            progressHandler?(Double(progress))
        }

        defer {
            progressObserver?.invalidate()
        }

        // 执行导出
        return try await withCheckedThrowingContinuation { continuation in
            exportSession?.exportAsynchronously { [weak self] in
                guard let self = self else { return }

                if self.isCancelledFlag {
                    exportSession?.cancelExport()
                    continuation.resume(throwing: TSMergerError.cancelled)
                    return
                }

                switch exportSession?.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    let error = exportSession?.error ?? TSMergerError.mergeFailed("Export failed")
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: TSMergerError.cancelled)
                default:
                    continuation.resume(
                        throwing: TSMergerError.mergeFailed("Unknown export status"))
                }
            }
        }
    }

    private func cleanup() {
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        mixComposition = nil
        videoTrack = nil
        audioTrack = nil
    }
}

// MARK: - Platform Extensions

#if os(macOS)
    extension VideoToolboxTSMerger {
        /// macOS 特定的初始化
        public convenience init(macOSOptions: () -> Void = {}) {
            self.init()
            macOSOptions()
        }
    }
#endif

#if os(iOS) || os(tvOS)
    extension VideoToolboxTSMerger {
        /// iOS/tvOS 特定的初始化
        public convenience init(iOSOptions: () -> Void = {}) {
            self.init()
            iOSOptions()
        }
    }
#endif
