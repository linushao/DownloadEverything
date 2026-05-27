---
alwaysApply: false
description: DownloadApp 编码规范与开发指南
---
# DownloadApp 编码规范与开发指南

## 1. 概述

本文档定义了 DownloadApp 项目的编码规范、最佳实践和开发流程。所有贡献者必须遵守本规范，以确保代码质量、一致性和可维护性。

### 1.1 项目规则继承

本规则继承自 `project_rules.md`，包含以下核心原则：
- 每一步如有不清楚的地方先问清楚再执行，可提供建议选项
- 根据安排文档完成任务后，修改相应的任务状态
- 如涉及搜索代码，使用 codegraph 搜索
- 如要编译 iOS 项目，使用已打开的 iPhone 16 模拟器、iOS 18.3 编译，不要新增模拟器
- 代码中不要用 magic number 和 magic string，用常量或环境变量代替
- 尽量使用面向协议的编程

---

## 2. 代码格式化规范

### 2.1 缩进与空格

- 使用 4 个空格缩进（项目已配置 swift-format）
- 不要使用 Tab 字符
- 在冒号前不加空格，冒号后加一个空格
- 在逗号后加一个空格

### 2.2 空行使用

- 文件以空行结尾
- 类型定义之间至少空一行
- 函数实现之间至少空一行
- MARK 注释前后各空一行

### 2.3 行长限制

- 单行长建议不超过 120 字符
- 超过时进行合理换行

### 2.4 Swift-Format

- 使用项目配置的 `.vscode/.swift-format` 进行代码格式化
- 提交代码前确保代码已格式化

---

## 3. 命名约定

### 3.1 通用规则

- 使用 descriptive 且清晰的命名
- 避免使用缩写，除非是广泛认知的缩写（如 URL、API、ID）
- 使用驼峰命名法（camelCase）

### 3.2 类型命名

- 使用大驼峰命名法（UpperCamelCase）
- 类名、结构体名、枚举名、协议名等遵循此规则
- 类名应包含名词，如 `DownloadManager`、`FileUtils`

### 3.3 函数与变量命名

- 使用小驼峰命名法（lowerCamelCase）
- 函数名应以动词开头，如 `startTask()`、`pauseTask()`
- 布尔值应使用 `is`、`has`、`can` 等前缀，如 `isDownloading`、`hasResumeData`

### 3.4 常量命名

- 使用小驼峰命名法（lowerCamelCase）作为实例常量
- 使用枚举或结构体组织全局常量
- 避免使用魔术数字，定义为常量

### 3.5 协议命名

- 使用描述性名称，描述协议职责
- 对于能力型协议，使用 -able/-ible 后缀，如 `Downloadable`、`Shareable`

---

## 4. 代码组织与架构

### 4.1 项目架构

遵循分层架构 + MVVM 模式：
- **UI 层**：SwiftUI Views
- **视图模型层**：ViewModels
- **业务逻辑层**：Services（如 DownloadManager）
- **数据访问层**：Repositories
- **基础设施层**：Core Data、URLSession、FileManager

### 4.2 文件组织

```
DownloadManager/
├── DownloadAppShared/
│   ├── Core/           # 核心业务逻辑
│   ├── Data/           # 数据访问层
│   ├── Network/        # 网络层
│   ├── UI/             # 视图相关
│   └── Utils/          # 工具类
└── DownloadManager.xcdatamodeld/
```

### 4.3 类型内部组织

使用 MARK 注释组织代码：

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Protocol Conformance
```

---

## 5. 面向协议编程

### 5.1 协议定义

优先定义协议，再实现具体类：

```swift
protocol DownloadTaskProtocol {
    var taskId: UUID { get }
    var url: URL { get }
    func start(session: URLSession)
    func pause()
}
```

### 5.2 协议扩展

使用协议扩展提供默认实现：

```swift
extension DownloadTaskProtocol {
    var progress: Double {
        // 默认实现
    }
}
```

---

## 6. 避免魔术数字与魔术字符串

### 6.1 使用常量定义

```swift
// 正确做法
enum DownloadConfig {
    static let maxConcurrentTasks = 4
    static let defaultRetryDelay: TimeInterval = 2.0
    static let maxRetryCount = 3
    static let requestTimeout: TimeInterval = 60
}

// 或使用结构体
struct AppConstants {
    static let defaultFileName = "unknown"
    static let downloadsDirectoryName = "Downloads"
}
```

### 6.2 使用枚举

```swift
enum DownloadStatus: Int16 {
    case waiting = 0
    case downloading = 1
    case paused = 2
    case completed = 3
    case failed = 4
}
```

---

## 7. 错误处理

### 7.1 定义错误类型

```swift
enum DownloadError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case fileError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .fileError(let error):
            return "文件错误: \(error.localizedDescription)"
        }
    }
}
```

### 7.2 使用 Result 类型

```swift
func downloadFile(url: URL, completion: @escaping (Result<URL, DownloadError>) -> Void) {
    // 实现
}
```

### 7.3 Swift Concurrency

优先使用 async/await 而不是回调：

```swift
func downloadFile(url: URL) async throws -> URL {
    // 实现
}
```

---

## 8. 线程安全

### 8.1 使用 DispatchQueue

```swift
private let queue = DispatchQueue(label: "com.downloadapp.downloadmanager", attributes: .concurrent)

func readData() -> T {
    queue.sync { /* 读取 */ }
}

func writeData() {
    queue.async(flags: .barrier) { /* 写入 */ }
}
```

### 8.2 使用 async/await 与 Actors

新代码优先使用 Actor 模型：

```swift
actor DownloadManager {
    // 实现
}
```

---

## 9. 内存管理

### 9.1 避免循环引用

使用 `[weak self]` 或 `[unowned self]`：

```swift
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
    guard let self = self else { return }
    // 实现
}
```

### 9.2 及时释放资源

```swift
deinit {
    timer?.invalidate()
    timer = nil
    notificationCenter.removeObserver(self)
}
```

---

## 10. 文档注释

### 10.1 公共 API 必须加文档

```swift
/// 下载管理器，负责管理所有下载任务
public final class DownloadManager {
    
    /// 添加下载任务
    /// - Parameters:
    ///   - url: 下载地址
    ///   - savePath: 保存路径（可选，默认下载目录）
    ///   - fileName: 文件名（可选，默认从 URL 获取）
    /// - Returns: 任务 ID
    @discardableResult
    public func addTask(url: URL, savePath: URL? = nil, fileName: String? = nil) -> UUID {
        // 实现
    }
}
```

### 10.2 使用 Markdown 格式

- 使用 `///` 而不是 `/** ... */`
- 使用 Markdown 语法
- 包含参数说明和返回值

---

## 11. 测试规范

### 11.1 单元测试

- 核心业务逻辑必须有单元测试
- 测试覆盖关键路径
- 使用 AAA 模式（Arrange-Act-Assert）

```swift
func testAddTask() {
    // Arrange
    let manager = DownloadManager()
    let url = URL(string: "https://example.com/file.zip")!
    
    // Act
    let taskId = manager.addTask(url: url)
    
    // Assert
    XCTAssertNotNil(manager.getTask(taskId: taskId))
}
```

### 11.2 UI 测试

- 关键用户流程应有 UI 测试
- 使用 Page Object 模式组织测试代码

---

## 12. 版本控制实践

### 12.1 提交信息规范

使用清晰的提交信息格式：

```
<type>(<scope>): <subject>

<body>

<footer>
```

类型（type）：
- feat: 新功能
- fix: 修复 bug
- docs: 文档更新
- style: 代码格式调整
- refactor: 重构
- test: 测试相关
- chore: 构建/工具相关

### 12.2 分支策略

- `main`: 主分支，稳定版本
- `feature/*`: 功能分支
- `bugfix/*`: 修复分支
- `hotfix/*`: 紧急修复分支

---

## 13. 代码审查清单

提交代码前，确保：
- [ ] 代码已格式化
- [ ] 无编译警告
- [ ] 单元测试通过
- [ ] 文档已更新
- [ ] 无硬编码的 magic number/string
- [ ] 遵循面向协议编程原则
- [ ] 内存管理正确，无循环引用
- [ ] 线程安全考虑周全
- [ ] 错误处理完善

---

## 14. 性能优化指南

### 14.1 下载优化

- 合理设置并发数（默认 4）
- 实现断点续传
- 支持速度限制

### 14.2 内存优化

- 按需加载数据
- 使用 NSCache 缓存图片
- 避免保留大对象
- 及时释放任务资源

### 14.3 启动优化

- 异步初始化非关键组件
- 懒加载模块
- 避免启动时繁重操作

---

## 15. 安全最佳实践

### 15.1 数据安全

- 使用 File Protection 保护敏感文件
- HTTPS 强制启用
- 验证 SSL 证书

### 15.2 输入验证

- 验证 URL 格式
- 限制文件路径
- 检查文件类型白名单

### 15.3 权限最小化

- 只请求必要权限
- 权限描述清晰

---

## 16. 附录

### 16.1 参考资源

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Swift Style Guide](https://google.github.io/swift/)

### 16.2 更新记录

- 2024-05-28: 初始版本创建
