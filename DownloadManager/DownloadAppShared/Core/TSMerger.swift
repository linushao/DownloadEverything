//
//  TSMerger.swift
//  DownloadManager
//
//

import Foundation

// MARK: - TSMergerError

public enum TSMergerError: LocalizedError {
    case fileNotFound
    case mergeFailed(String)
    case cancelled
    case ffmpegNotAvailable
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "文件未找到"
        case .mergeFailed(let message):
            return "合并失败: \(message)"
        case .cancelled:
            return "已取消"
        case .ffmpegNotAvailable:
            return "FFmpeg 不可用，请先集成 ffmpeg-kit"
        }
    }
}

// MARK: - TSMerger

/// TS 分片合并器
public final class TSMerger {
    
    // MARK: - Properties
    
    private let queue = DispatchQueue(label: "com.downloadapp.tsmerger")
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// 合并 TS 分片
    /// - Parameters:
    ///   - segments: 媒体分片列表
    ///   - task: 下载任务
    ///   - outputURL: 输出文件 URL
    ///   - progressHandler: 进度回调
    public func merge(
        segments: [MediaSegment],
        task: M3U8DownloadTask,
        outputURL: URL,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        // 创建文件列表
        let fileListURL = task.tempDirectory.appendingPathComponent("filelist.txt")
        var fileListContent = ""
        
        for (index, _) in segments.enumerated() {
            let segmentPath = task.tempSegmentPath(for: index).path
            guard FileManager.default.fileExists(atPath: segmentPath) else {
                throw TSMergerError.fileNotFound
            }
            fileListContent += "file '\(segmentPath)'\n"
        }
        
        try fileListContent.write(to: fileListURL, atomically: true, encoding: .utf8)
        
        // 合并文件
        let tempOutputURL = task.tempDirectory.appendingPathComponent("output.ts")
        try await concatenateFiles(from: fileListURL, to: tempOutputURL, progressHandler: progressHandler)
        
        // 转换为 MP4
        try await convertToMP4(input: tempOutputURL, output: outputURL, progressHandler: progressHandler)
        
        // 清理临时文件
        try? FileManager.default.removeItem(at: fileListURL)
        try? FileManager.default.removeItem(at: tempOutputURL)
    }
    
    /// 取消合并
    public func cancel() {
        // 可以在这里添加取消逻辑
    }
    
    // MARK: - Private Methods
    
    private func concatenateFiles(from fileListURL: URL, to outputURL: URL, progressHandler: ((Double) -> Void)?) async throws {
        // 简单的二进制拼接
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }
        
        fileManager.createFile(atPath: outputURL.path, contents: nil)
        
        guard let handle = FileHandle(forWritingAtPath: outputURL.path) else {
            throw TSMergerError.mergeFailed("无法创建输出文件")
        }
        
        defer {
            handle.closeFile()
        }
        
        // 读取文件列表
        let fileListContent = try String(contentsOf: fileListURL, encoding: .utf8)
        let lines = fileListContent.components(separatedBy: .newlines)
        let filePaths = lines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("file '") else { return nil }
            let pathPart = String(trimmed.dropFirst(6).dropLast())
            return pathPart
        }
        
        let totalFiles = filePaths.count
        var processedFiles = 0
        
        for filePath in filePaths {
            let fileURL = URL(fileURLWithPath: filePath)
            let data = try Data(contentsOf: fileURL)
            handle.write(data)
            
            processedFiles += 1
            let progress = Double(processedFiles) / Double(totalFiles) * 0.5 // 拼接占50%
            progressHandler?(progress)
        }
    }
    
    private func convertToMP4(input: URL, output: URL, progressHandler: ((Double) -> Void)?) async throws {
        // TODO: 这里需要集成 ffmpeg-kit 来进行格式转换
        // 临时实现：直接重命名文件
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: output.path) {
            try fileManager.removeItem(at: output)
        }
        
        try fileManager.copyItem(at: input, to: output)
        
        progressHandler?(1.0)
    }
}
