---
name: "tdd-development"
description: "iOS + macOS TDD(Test-Driven Development)开发流程。使用XCTest框架,严格遵循 Red-Green-Refactor 循环,覆盖单元测试、UI测试、CoreData测试、网络Mock、集成测试等场景。Invoke when user asks to add new feature, write tests, refactor code, fix bugs in TDD style, or mentions TDD/测试驱动/先写测试."
---

# TDD Development Skill (iOS / macOS + XCTest)

本 skill 用于在 DownloadApp 项目中以 **测试驱动开发 (TDD)** 方式交付代码变更。所有使用本 skill 完成的代码都必须严格遵循 **Red → Green → Refactor** 循环。

---

## 1. 何时调用本 Skill (智能触发规则)

**自动调用触发条件**（满足任意一条即应加载本 skill）:

| 场景 | 关键词示例 | 处理方式 |
| --- | --- | --- |
| 用户明确要求 TDD | "用TDD开发"、"测试驱动"、"先写测试" | 立即调用 |
| 新增功能 / 新模块 | "添加xxx功能"、"新增xxx类/服务/View" | 立即调用 |
| 修复 Bug | "修复bug"、"修这个问题" | 立即调用 |
| 重构代码 | "重构"、"优化代码结构"、"clean code" | 立即调用 |
| 编写测试 | "写个测试"、"加单元测试"、"补测试用例" | 立即调用 |
| 编写 ViewModel / Service | 涉及 `ViewModel`、`Service`、`Manager`、`Repository` 的新增 | 立即调用 |
| 接口契约变更 | "改xxx接口"、"xxx协议调整" | 立即调用 |

**不调用的场景**:
- 纯文档修改（.md 文件）
- 资源文件调整（图片、颜色配置）
- 项目配置（Podfile、Info.plist、project.pbxproj）但不影响逻辑
- 用户明确说"直接写、不用TDD"

---

## 2. TDD 三步循环 (Red-Green-Refactor)

### 🔴 Step 1: Red — 写一个失败的测试

1. **先写测试，后写实现**。在写任何产品代码前，先在 `DownloadManagerTests/` 目录下新增或扩展测试文件。
2. 测试文件命名：`{目标类型}Tests.swift`，与 `DownloadManager/` 源码一一对应。
3. 测试方法命名遵循已有项目风格：`testXxxYyy`（见 `M3U8ParserTests.swift`、`NetworkServiceTests.swift`）。
4. 测试必须明确表达**意图**和**期望行为**，不要在测试中复刻实现细节。
5. 一个测试只验证一个行为点；多个行为点拆成多个 `testXxx` 方法。
6. 运行测试确认 **失败**（不是因为编译错误，而是断言失败），证明测试本身有效。

**Red 阶段检查清单**:
- [ ] 测试文件放在 `DownloadManagerTests/` 目录
- [ ] 使用 `@testable import DownloadManager`
- [ ] `setUp` 中初始化被测对象与 Mock
- [ ] `tearDown` 中置空引用，避免状态污染
- [ ] 断言使用 `XCTAssert*` 系列
- [ ] 测试运行后**确认失败**（且失败原因符合预期）

### 🟢 Step 2: Green — 写最简实现让测试通过

1. 编写**最简单、最直接**的实现，让上一步的测试通过。
2. **不要在 Red 阶段追求设计**。允许重复、允许丑陋，只要能通过。
3. 写完后运行测试，必须看到 **绿灯**。
4. 如果实现涉及多个层（UI/ViewModel/Service/Data），从最内层（纯逻辑/数据）开始往外推。

**Green 阶段检查清单**:
- [ ] 新增/修改的代码在 `DownloadManager/DownloadAppShared/` 对应分层目录下
- [ ] 分层归属正确：业务 → `Core/`、数据 → `Data/`、网络 → `Network/`、UI → `UI/`、工具 → `Utils/`
- [ ] 遵循 `coding_rules.md` 编码规范（4空格缩进、命名约定、避免magic number等）
- [ ] 所有相关测试**通过**（包括历史测试）
- [ ] **不引入新的失败测试**

### 🔵 Step 3: Refactor — 在测试保护下改善设计

1. **仅在测试全绿后**进行重构。重构过程中**不允许修改行为**。
2. 改进点包括：消除重复、提取协议、拆分大类、用常量替代 magic number、面向协议编程、改进命名。
3. 每改一处运行一次测试，确保持续绿灯。
4. 重构后**所有测试（包括新写的）必须仍然通过**。
5. 如果发现测试覆盖不足，**补写新测试**（此时再走一次 Red-Green-Refactor）。

**Refactor 阶段检查清单**:
- [ ] 没有改变对外可观察的行为
- [ ] 代码遵循面向协议编程原则
- [ ] 没有引入新的 magic number / magic string
- [ ] 没有破坏既有测试
- [ ] 代码已用 `.swift-format` 格式化

---

## 3. 测试分层与组织

### 3.1 项目结构约定

```
DownloadManager/
├── DownloadAppShared/         # 生产代码（被测对象）
│   ├── Core/                  # 业务逻辑
│   ├── Data/                  # 数据访问、CoreData
│   ├── Models/                # 领域模型
│   ├── Network/               # 网络层
│   ├── UI/                    # SwiftUI Views / ViewModels
│   └── Utils/                 # 工具
└── DownloadManagerTests/      # 测试代码
    ├── CoreDataTestHelper.swift
    ├── M3U8ParserTests.swift           # 单元测试样例
    ├── NetworkServiceTests.swift       # 网络 Mock 样例
    ├── M3U8DownloaderTests.swift
    ├── M3U8IntegrationTests.swift      # 集成测试
    ├── SnapshotTests.swift             # 快照测试
    ├── TSMergerTests.swift
    └── ShareManagerTests.swift
```

### 3.2 测试类型与策略

| 测试类型 | 目标 | Mock 策略 | 典型场景 |
| --- | --- | --- | --- |
| **单元测试** | 单个类/函数/struct | 通过协议注入 Mock 依赖 | `M3U8ParserTests`、`TSMergerTests` |
| **网络层测试** | URLSession / Alamofire 请求 | `MockURLProtocol` 拦截请求 | `NetworkServiceTests` |
| **CoreData 测试** | 持久化逻辑 | `CoreDataTestHelper` 提供内存数据库 | `CoreDataTestHelper.swift` |
| **集成测试** | 多个模块协作 | 部分真实 + 部分 Mock | `M3U8IntegrationTests` |
| **快照测试** | UI 渲染结果 | 不需要 Mock | `SnapshotTests` |

### 3.3 Mock 编写规范

1. **优先使用协议注入**：被测类应通过协议（如 `NetworkService`）接收依赖，便于在测试中替换为 Mock。
2. **Mock 命名**：`Mock{协议名}`，如 `MockNetworkService`、`MockURLProtocol`。
3. **Mock 集中管理**：通用 Mock 放在单独文件，避免每个测试文件重复造轮子。
4. **测试结束后清理 Mock 状态**（在 `tearDown` 中重置 handler、置空引用等）。

参考既有 Mock：
- `MockNetworkService`：用于 `M3U8ParserTests`
- `MockURLProtocol`：用于 `NetworkServiceTests`（拦截 Alamofire 请求）

---

## 4. XCTest 编写规范

### 4.1 基础模板

```swift
import XCTest
@testable import DownloadManager

final class TargetTypeTests: XCTestCase {

    var sut: TargetType!            // System Under Test
    var mockDependency: MockDependency!

    override func setUp() {
        super.setUp()
        mockDependency = MockDependency()
        sut = TargetType(dependency: mockDependency)
    }

    override func tearDown() {
        sut = nil
        mockDependency = nil
        super.tearDown()
    }

    // MARK: - Behavior Group

    func testXxxShouldDoYyyWhenCondition() throws {
        // Given
        let input = ...

        // When
        let result = try sut.doSomething(with: input)

        // Then
        XCTAssertEqual(result.expected, actual)
    }
}
```

### 4.2 断言使用约定

- 优先使用最具体的断言：`XCTAssertEqual` > `XCTAssertTrue`
- 集合比较：`XCTAssertEqual(items, [expected])`
- 错误抛出：`XCTAssertThrowsError`、`XCTAssertNoThrow`
- 异步测试：使用 `expectation(description:)` + `wait(for:timeout:)`
- 性能测试：使用 `measure { }` 块（仅在确实需要性能保证时）

### 4.3 命名规范

- **测试类**：`{被测类型}Tests`，如 `M3U8ParserTests`
- **测试方法**：`test{行为描述}_{场景}_{期望结果}`，如 `testParseSimpleM3U8`、`testParseM3U8WithNoEXTINF`
- **MARK 分组**：用 `// MARK: - {分组名}` 按行为/场景分组

### 4.4 异步与并发

- iOS 15+ 优先用 `async/await` + `XCTestExpectation` 或 `await sut.method()` 直接等待
- iOS 13+ 用 `expectation` + `wait(for:timeout:)`，timeout 不要超过 10s
- 涉及下载/网络时，使用 `MockURLProtocol` 避免真实网络请求

---

## 5. TDD 工作流（在 IDE 中执行）

当用户请求 TDD 开发某功能时，按以下顺序推进：

1. **澄清需求**（如有不清楚，先用 `AskUserQuestion` 询问）
2. **分析影响范围**：定位要修改/新增的源码文件（搜索用 codegraph）
3. **🔴 Red**：在 `DownloadManagerTests/` 新建或扩展测试文件，写失败测试
4. **运行测试确认失败**（使用 xcodebuild test 或在 IDE 中运行）
5. **🟢 Green**：在 `DownloadManager/DownloadAppShared/` 对应分层中写最简实现
6. **运行测试确认通过**
7. **🔵 Refactor**：在测试保护下改善设计
8. **运行完整测试套件**确保无回归
9. **汇报结果**：列出新增/修改的测试用例与实现文件

---

## 6. 验收标准（Definition of Done）

完成一个 TDD 任务必须满足：

- [ ] 所有新增功能都有对应的失败-通过测试记录
- [ ] `DownloadManagerTests/` 下新增的测试文件命名符合规范
- [ ] 既有测试全部通过，无回归
- [ ] 生产代码遵循 `coding_rules.md`
- [ ] 使用 `.swift-format` 格式化
- [ ] 没有引入新的 magic number / magic string
- [ ] 复杂逻辑有清晰的协议抽象
- [ ] 如有 UI 变更，补充 SwiftUI 预览或快照测试

---

## 7. 常见反模式（必须避免）

| ❌ 反模式 | ✅ 正解 |
| --- | --- |
| 先写实现，后补测试 | 严格 Red-Green-Refactor |
| 一个测试方法验证多个不相关行为 | 拆分成多个 test 方法 |
| 测试中包含业务逻辑 | 测试只表达期望，不复刻实现 |
| 在生产代码中使用 Mock 类型 | 通过协议注入，Mock 仅存在于测试中 |
| 测试方法间共享可变状态 | 每个测试独立 setUp/tearDown |
| `XCTAssertTrue(result == 42)` | `XCTAssertEqual(result, 42)` |
| 在测试中调用真实网络/磁盘 | 使用 MockURLProtocol / 内存 CoreData |
| 修改实现后忘记更新测试 | 测试反映**期望行为**，不是实现细节 |

---

## 8. 与项目其他规则的协作

- **编码规范**：遵循 `.trae/rules/coding_rules.md`
- **项目规则**：遵循 `.trae/rules/project_rules.md`（编译用 iPhone 17 模拟器 iOS 26.5、codegraph 搜索等）
- **任务文档**：在 `doc/` 目录的任务清单中勾选完成状态
- **CocoaPods**：第三方库统一通过 Podfile 管理（如 Alamofire、OHTTPStubs 等）

---

## 9. 快速检查清单（每次 TDD 任务结束时自检）

- [ ] 是否先写了失败测试？
- [ ] 是否确认了测试因为业务原因失败（而非编译错误）？
- [ ] 实现是否是最简单的"让测试通过"的版本？
- [ ] 重构后所有测试是否仍然通过？
- [ ] 是否运行了完整测试套件，无回归？
- [ ] 代码是否已格式化、遵循命名规范？
- [ ] 是否更新了 `doc/` 中相应的任务清单？
