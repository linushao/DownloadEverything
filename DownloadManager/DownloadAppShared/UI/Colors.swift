import SwiftUI

/// 应用颜色主题
enum AppColors {
    /// 悬停背景色
    static let hoverBackground = Color.gray.opacity(0.1)

    /// 背景色（适配Dark Mode）
    static let background = Platform.colorProvider.background

    /// 次要背景色
    static let secondaryBackground = Platform.colorProvider.secondaryBackground

    /// 分割线颜色
    static let divider = Platform.colorProvider.divider
}
