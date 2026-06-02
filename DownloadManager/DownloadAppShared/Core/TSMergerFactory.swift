//
//  TSMergerFactory.swift
//  DownloadManager
//
//  Created by TDD Assistant on 2026/6/2.
//

import Foundation

// MARK: - TSMergerEngine

/// TS 合并引擎类型
public enum TSMergerEngine {
    /// 使用 VideoToolbox（硬件加速）
    case videoToolbox
}

// MARK: - TSMergerFactory

/// TS 合并器工厂类
public enum TSMergerFactory {
    /// 创建默认的合并器（使用 VideoToolbox 硬件加速）
    public static func makeDefault() -> TSMergerProtocol {
        return makeVideoToolbox()
    }

    /// 创建 VideoToolbox 合并器
    public static func makeVideoToolbox() -> TSMergerProtocol {
        return VideoToolboxTSMerger()
    }

    /// 创建指定类型的合并器
    public static func make(engine: TSMergerEngine) -> TSMergerProtocol {
        switch engine {
        case .videoToolbox:
            return makeVideoToolbox()
        }
    }
}