# 项目原生网络请求迁移至 Alamofire 计划

## 一、背景与目标

将项目中基于原生 `URLSession` 的网络请求代码迁移到 `Alamofire`，以获得更好的网络请求管理、错误处理和代码可维护性。

### 需要迁移的组件

1. **NetworkService.swift** - HTTP 请求服务（GET/POST/HEAD）
2. **DownloadTask.swift** - 文件下载任务管理
3. **DownloadManager.swift** - 下载任务管理器
4. **NetworkServiceTests.swift** - 单元测试

---

## 二、迁移步骤

### 阶段 1：依赖管理配置

#### 1.1 选择依赖管理方式
- **推荐方式**：Swift Package Manager (SPM)
- **备选方式**：CocoaPods

#### 1.2 添加 Alamofire 依赖
- 通过 SPM 或 CocoaPods 添加 Alamofire
- 确保版本兼容性（推荐使用最新稳定版）

---

### 阶段 2：NetworkService 迁移

#### 2.1 迁移 HTTP 请求方法

| 原方法 | Alamofire 对应 |
|--------|----------------|
| `get(url:headers:)` | `AF.request(...).serializingData()` |
| `get<T>(_:url:headers:)` | `AF.request(...).decodable()` |
| `post(url:body:headers:)` | `AF.request(..., method: .post)` |
| `post<T:B:>(url:body:headers:)` | `AF.request(..., method: .post)` |
| `head(url:headers:)` | `AF.request(..., method: .head)` |

#### 2.2 错误处理适配
- 将 Alamofire 的 `AFError` 映射到现有的 `NetworkError`
- 保持错误类型的兼容性

#### 2.3 配置保留
- 保持会话配置的可配置性
- 支持超时设置、最大连接数等

---

### 阶段 3：DownloadTask 与 DownloadManager 迁移

#### 3.1 文件下载策略选择

**策略 A：继续使用 URLSessionDownloadTask**
- 优点：完全控制下载进度、resumeData、速度限制
- 缺点：需要同时维护两套网络代码

**策略 B：使用 Alamofire DownloadRequest**
- 优点：统一网络层代码
- 缺点：需要适配 Alamofire 的下载 API

#### 3.2 推荐方案

**采用策略 A**：保留现有的 `URLSessionDownloadTask` 机制
- 下载功能与普通 HTTP 请求不同，需要细粒度控制
- Alamofire 适合普通请求，不适合复杂下载场景

---

### 阶段 4：测试代码适配

#### 4.1 更新 NetworkServiceTests
- 使用 Alamofire 的请求 mock 机制
- 或保持 MockURLProtocol 方式

#### 4.2 确保测试覆盖
- GET 请求测试
- POST 请求测试
- HEAD 请求测试
- 错误处理测试

---

## 三、具体实现计划

### 步骤 1：添加依赖
```
1.1 选择依赖管理方式（SPM/CocoaPods）
1.2 添加 Alamofire 到项目
1.3 验证编译通过
```

### 步骤 2：创建 Alamofire 封装层
```
2.1 创建 AlamofireNetworkService
2.2 保留 NetworkService 接口兼容性
2.3 实现错误映射
```

### 步骤 3：迁移 NetworkService
```
3.1 将 URLSession 替换为 Alamofire Session
3.2 更新所有请求方法
3.3 保持测试兼容性
```

### 步骤 4：处理下载功能
```
4.1 评估是否迁移下载功能到 Alamofire
4.2 如需迁移，实现 DownloadRequest 封装
4.3 如保持原方案，更新 URLSession 配置
```

### 步骤 5：测试与验证
```
5.1 更新单元测试
5.2 运行测试确保通过
5.3 编译项目验证
```

---

## 四、关键考虑点

### 4.1 API 兼容性
- 保持现有公开 API 不变
- 内部实现可自由修改

### 4.2 错误处理
- 确保错误类型兼容
- 提供清晰的错误信息

### 4.3 性能
- Alamofire 有更好的并发管理
- 需要测试性能是否有提升

### 4.4 代码量
- NetworkService: ~280 行 → ~250 行
- 测试代码需要同步更新

---

## 五、风险与应对

| 风险 | 影响 | 应对措施 |
|------|------|----------|
| API 兼容性问题 | 高 | 保持接口不变 |
| 测试失败 | 中 | 同步更新测试代码 |
| 编译错误 | 中 | 逐步迁移，及时编译验证 |

---

## 六、预期结果

- ✅ NetworkService 使用 Alamofire 实现
- ✅ 保持所有公开 API 不变
- ✅ 单元测试全部通过
- ✅ 项目编译成功
- ❌ 下载功能保持原实现（推荐方案）

---

## 七、后续优化建议

迁移完成后可以考虑：
1. 使用 Alamofire 的请求拦截器功能
2. 统一错误处理
3. 添加网络状态监控
