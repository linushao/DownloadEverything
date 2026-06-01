---
name: coding_rules
description: DownloadApp (iOS/Swift) 项目的编码规范、命名约定、架构分层、错误处理、测试、提交信息与代码审查清单。Invoke when 用户提到「按项目规范写」「代码风格/格式化」「命名约定/驼峰/MVVM 分层/面向协议」「magic number」「提交信息规范」「git 分支策略」「code review 清单」，或新建/修改 Swift 文件时被要求「参考项目规范」。
alwaysApply: false
---
# DownloadApp 编码规范与开发指南

## 1. 概述

本文档定义 DownloadApp 项目的编码规范、最佳实践和开发流程。

### 1.1 硬性原则（执行前必读）

- **先问再做**：每一步如有不清楚的地方先问清楚再执行，可提供建议选项
- **中文沟通**：全程使用中文回复用户
- **本规范优先**：修改代码前先参考本文档

### 1.2 项目规则继承

- 根据安排文档完成任务后，修改相应的任务状态
- 如涉及搜索代码，使用 codegraph 搜索（详见附录 A）
- 如要编译 iOS 项目，使用当前已打开的模拟器编译，不要新增模拟器
- 代码规范详见第 6 节
- 尽量使用面向协议的编程
- **第三方库统一通过 CocoaPods 管理**（以 `Podfile` 为准；新增依赖必须同步更新 `Podfile` 与 `Podfile.lock` 并纳入版本控制）

---

## 2. 代码格式化规范

- 使用 4 个空格缩进
- 不要使用 Tab 字符
- 冒号前不加空格，冒号后加一个空格
- 逗号后加一个空格
- 文件以空行结尾
- 类型定义、函数实现之间至少空一行
- MARK 注释前后各空一行
- 单行长建议不超过 120 字符
- 使用项目配置的 `.vscode/.swift-format` 进行代码格式化

---

## 3. 命名约定

### 3.1 通用规则
- 使用 descriptive 且清晰的命名
- 避免使用缩写，除非是广泛认知的缩写（如 URL、API、ID）
- 使用驼峰命名法（camelCase）

### 3.2 类型命名
- 使用大驼峰命名法（UpperCamelCase）：类名、结构体名、枚举名、协议名

### 3.3 函数与变量命名
- 使用小驼峰命名法（lowerCamelCase）
- 函数名应以动词开头，如 `startTask()`、`pauseTask()`
- 布尔值应使用 `is`、`has`、`can` 等前缀

**反例**：

```swift
// ❌ 函数名不是动词开头
func taskStatus() -> Status { ... }

// ❌ 布尔值缺前缀
var downloading: Bool = false

// ✅ 正确写法
func getTaskStatus() -> Status { ... }
var isDownloading: Bool = false
```

### 3.4 常量命名
- 使用小驼峰命名法（lowerCamelCase）作为实例常量
- 使用枚举或结构体组织全局常量
- 避免使用魔术数字，定义为常量

### 3.5 协议命名
- 使用描述性名称，描述协议职责
- 对于能力型协议，使用 -able/-ible 后缀

---

## 4. 代码组织与架构

### 4.1 项目架构
遵循分层架构 + MVVM 模式：
- UI 层：SwiftUI Views
- 视图模型层：ViewModels
- 业务逻辑层：Services
- 数据访问层：Repositories
- 基础设施层：Core Data、URLSession、FileManager

### 4.2 文件组织
```
DownloadManager/
├── DownloadAppShared/
│   ├── Core/
│   ├── Data/
│   ├── Models/
│   ├── Network/
│   ├── UI/
│   └── Utils/
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

优先定义协议，再实现具体类。使用协议扩展提供默认实现。

**反例**：

```swift
// ❌ 直接依赖具体类，难替换、难测试
final class DownloadManager {
    let http: NetworkService
}

// ✅ 依赖协议，便于 Mock 与替换
protocol NetworkServiceProtocol {
    func get(url: URL) async throws -> Data
}
final class DownloadManager {
    let http: NetworkServiceProtocol
}
```

---

## 6. 避免魔术数字与魔术字符串

使用枚举或结构体组织常量：
```swift
enum DownloadConfig {
    static let maxConcurrentTasks = 4
    static let defaultRetryDelay: TimeInterval = 2.0
}

enum DownloadStatus: Int16 {
    case waiting = 0, downloading = 1, paused = 2, completed = 3, failed = 4
}
```

---

## 7. 错误处理

定义错误类型遵循 `LocalizedError`，优先使用 async/await 而不是回调。

**反例**：

```swift
// ❌ 用字符串/裸 NSError 表达业务错误，调用方无法穷举处理
throw NSError(domain: "Download", code: -1)

// ❌ 回调嵌套，可读性差、错误传播繁琐
func download(url: URL, completion: @escaping (Result<Data, Error>) -> Void) { ... }

// ✅ 推荐：枚举错误 + async/await
enum DownloadError: LocalizedError {
    case invalidURL
    case networkUnavailable
    case taskNotFound
    var errorDescription: String? { ... }
}

func download(url: URL) async throws -> Data { ... }
```

---

## 8. 线程安全

新代码优先使用 Actor 模型。

---

## 9. 内存管理

使用 `[weak self]` 或 `[unowned self]` 避免循环引用，在 `deinit` 中及时释放资源。

**反例**：

```swift
// ❌ 闭包直接强引用 self，可能造成循环引用
URLSession.shared.dataTask(with: url) { data, _, _ in
    self.handle(data)
}.resume()

// ✅ 正确写法
URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
    self?.handle(data)
}.resume()
```

---

## 10. 文档注释

公共 API 必须加文档，使用 `///` 和 Markdown 语法。

---

## 11. 测试规范

- 核心业务逻辑必须有单元测试，使用 AAA 模式
- 关键用户流程应有 UI 测试，使用 Page Object 模式
- **测试流程遵循 TDD**：严格遵循 Red → Green → Refactor 循环，详见 [tdd-development skill](.trae/skills/tdd-development/SKILL.md)

---

## 12. 版本控制实践

### 12.1 提交信息规范
```
<type>(<scope>): <subject>

[body]（可选）

[footer]（可选）
```
类型（必填）：feat, fix, docs, style, refactor, test, chore

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

- 下载：合理设置并发数，实现断点续传
- 内存：按需加载，使用 NSCache，及时释放资源
- 启动：异步初始化，懒加载模块

---

## 15. 安全最佳实践

- 使用 File Protection 保护敏感文件
- HTTPS 强制启用，验证 SSL 证书
- 验证 URL 格式，限制文件路径
- 只请求必要权限

---

## 附录 A: codegraph 工具

codegraph 是项目的代码搜索工具，用于快速定位代码中的符号、函数、类型等。常用命令：

```bash
# 搜索函数或方法
codegraph search <function_name>

# 搜索类型定义
codegraph search --type <type_name>
```

> 完整子命令与参数请参考 `.codegraph/` 目录下的工具自带文档。

---

## 16. 附录

### 16.1 参考资源
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Swift Style Guide](https://google.github.io/swift/)

### 16.2 更新记录
- 2024-05-28: 初始版本创建
- 2026-06-02: 精简优化
- 2026-06-02: 补全 frontmatter 触发词、修正章节编号、补 Models/、关联 tdd-development skill、统一依赖管理口径为 Podfile、关键章节补充反例

