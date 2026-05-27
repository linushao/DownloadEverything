import SwiftUI

// MARK: - ColorProviding Protocol

/// 跨平台颜色提供协议
protocol ColorProviding {
    /// 背景色
    static var background: Color { get }

    /// 次要背景色
    static var secondaryBackground: Color { get }

    /// 分割线颜色
    static var divider: Color { get }
}

/// 平台相关的适配工具
enum Platform {
    /// 是否是macOS平台
    static let isMacOS: Bool = {
        #if os(macOS)
            return true
        #else
            return false
        #endif
    }()

    /// 是否是iOS平台
    static let isiOS: Bool = {
        #if os(iOS)
            return true
        #else
            return false
        #endif
    }()

    /// 获取当前平台的颜色提供器
    static let colorProvider: ColorProviding.Type = {
        #if os(iOS)
            return iOSColorProvider.self
        #else
            return macOSColorProvider.self
        #endif
    }()
}

// MARK: - Platform-Specific Color Providers

#if os(iOS)
    import UIKit

    enum iOSColorProvider: ColorProviding {
        static var background: Color {
            Color(UIColor.systemBackground)
        }

        static var secondaryBackground: Color {
            Color(UIColor.secondarySystemBackground)
        }

        static var divider: Color {
            Color(UIColor.separator)
        }
    }
#else
    import AppKit

    enum macOSColorProvider: ColorProviding {
        static var background: Color {
            Color(NSColor.windowBackgroundColor)
        }

        static var secondaryBackground: Color {
            Color(NSColor.controlBackgroundColor)
        }

        static var divider: Color {
            Color(NSColor.separatorColor)
        }
    }
#endif

// MARK: - View Extensions for Platform Adaptation

extension View {
    /// 仅在macOS上应用help提示
    func platformHelp(_ text: String) -> some View {
        #if os(macOS)
            return self.help(text)
        #else
            return self
        #endif
    }

    /// 应用平台特定的窗口样式
    func platformWindowStyle() -> some View {
        #if os(macOS)
            return self.frame(minWidth: 800, minHeight: 600)
        #else
            return self
        #endif
    }

    /// 应用平台特定的导航样式
    func platformNavigationStyle() -> some View {
        #if os(iOS)
            return self.navigationViewStyle(.stack)
        #else
            return self
        #endif
    }
}
