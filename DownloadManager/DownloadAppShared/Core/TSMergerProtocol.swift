//
//  TSMergerProtocol.swift
//  DownloadManager
//
//  Created by TDD Assistant on 2026/6/2.
//

import Foundation

// MARK: - TSMergerError

/// TS 分片合并错误类型
public enum TSMergerError: LocalizedError, Equatable {
    /// 文件未找到
    case fileNotFound
    /// 操作已取消
    case cancelled
    /// 合并失败
    case mergeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "TS segment file not found"
        case .cancelled:
            return "Merge operation was cancelled"
        case .mergeFailed(let message):
            return "Merge failed: \(message)"
        }
    }

    public static func == (lhs: TSMergerError, rhs: TSMergerError) -> Bool {
        switch (lhs, rhs) {
        case (.fileNotFound, .fileNotFound):
            return true
        case (.cancelled, .cancelled):
            return true
        case (.mergeFailed(let lhsMsg), .mergeFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

// MARK: - TSMergerProtocol

/// TS 分片合并器协议
public protocol TSMergerProtocol {
    /// 合并 TS 分片
    /// - Parameters:
    ///   - segments: 媒体分片列表
    ///   - task: 下载任务
    ///   - outputURL: 输出文件 URL
    ///   - progressHandler: 进度回调（0.0 ~ 1.0）
    func merge(
        segments: [MediaSegment],
        task: M3U8DownloadTask,
        outputURL: URL,
        progressHandler: ((Double) -> Void)?
    ) async throws

    /// 取消合并
    func cancel()
}
