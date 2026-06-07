import Alamofire
import Foundation

/// 网络服务错误类型
public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingFailed
    case serverError(statusCode: Int)
    case networkError(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "服务器未返回数据"
        case .decodingFailed:
            return "数据解析失败"
        case .serverError(let statusCode):
            return "服务器错误: \(statusCode)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "服务器未返回数据"
        case .decodingFailed:
            return "数据解析失败"
        case .serverError(let statusCode):
            return "服务器错误: \(statusCode)"
        case .networkError(let error):
            return error.localizedDescription
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "请检查URL是否正确"
        case .noData:
            return "请稍后重试"
        case .decodingFailed:
            return "请检查数据格式"
        case .serverError:
            return "请稍后重试"
        case .networkError:
            return "请检查网络连接"
        }
    }

    public var urlErrorCode: Int {
        switch self {
        case .invalidURL:
            return NSURLErrorBadURL
        case .noData:
            return NSURLErrorCannotDecodeContentData
        case .decodingFailed:
            return NSURLErrorCannotDecodeContentData
        case .serverError(let statusCode):
            return statusCode == 404 ? NSURLErrorFileDoesNotExist : NSURLErrorBadServerResponse
        case .networkError:
            return NSURLErrorNetworkConnectionLost
        }
    }

    public var asNSError: NSError {
        return NSError(
            domain: NSURLErrorDomain, code: urlErrorCode,
            userInfo: [
                NSLocalizedDescriptionKey: errorDescription ?? "",
                NSLocalizedFailureReasonErrorKey: failureReason ?? "",
                NSLocalizedRecoverySuggestionErrorKey: recoverySuggestion ?? "",
            ])
    }
}

extension AFError {
    func toNetworkError() -> NetworkError {
        switch self {
        case .invalidURL:
            return .invalidURL
        case .responseSerializationFailed:
            return .decodingFailed
        case .serverTrustEvaluationFailed,
            .urlRequestValidationFailed:
            return .networkError(underlying: self)
        default:
            if let underlyingError = self.underlyingError {
                return .networkError(underlying: underlyingError)
            }
            return .networkError(underlying: self)
        }
    }
}

/// 网络服务协议
public protocol NetworkServiceProtocol: Sendable {
    func get(url: URL, headers: [String: String]?) async throws -> Data
}

/// 网络服务类，基于Alamofire封装网络请求
public final class NetworkService: NetworkServiceProtocol {

    // MARK: - Singleton

    public static let shared = NetworkService()

    // MARK: - Properties

    private let session: Session

    private var requestTimeout: TimeInterval = 30
    private var resourceTimeout: TimeInterval = 300
    private var maxConnectionsPerHost: Int = 4

    // MARK: - Testing

    private var isMockMode: Bool = false
    private var mockSession: Session?

    // MARK: - Initialization

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.httpMaximumConnectionsPerHost = maxConnectionsPerHost

        session = Session(configuration: configuration)
    }

    // MARK: - GET Request

    /// 发起GET请求
    public func get(url: URL, headers: [String: String]? = nil) async throws -> Data {
        let method = HTTPMethod.get
        let httpHeaders = HTTPHeaders(mergedHeaders(with: headers))

        return try await withCheckedThrowingContinuation { continuation in
            activeSession.request(url, method: method, headers: httpHeaders)
                .validate(statusCode: 200..<300)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        let networkError = self.mapError(error, response: response.response)
                        continuation.resume(throwing: networkError)
                    }
                }
        }
    }

    /// 发起GET请求并解码为指定类型
    public func get<T: Decodable>(_ type: T.Type, url: URL, headers: [String: String]? = nil)
        async throws -> T
    {
        let data = try await get(url: url, headers: headers)

        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            throw NetworkError.decodingFailed
        }
    }

    // MARK: - POST Request

    /// 发起POST请求
    public func post(url: URL, body: Data?, headers: [String: String]? = nil) async throws -> Data {
        let method = HTTPMethod.post
        var httpHeaders = HTTPHeaders(mergedHeaders(with: headers))

        if body != nil {
            httpHeaders.add(name: "Content-Type", value: "application/json")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.headers = httpHeaders

        return try await withCheckedThrowingContinuation { continuation in
            activeSession.request(request)
                .validate(statusCode: 200..<300)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        let networkError = self.mapError(error, response: response.response)
                        continuation.resume(throwing: networkError)
                    }
                }
        }
    }

    /// 发起POST请求并解码为指定类型
    public func post<T: Decodable, B: Encodable>(
        url: URL, body: B, headers: [String: String]? = nil
    ) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)

        let data = try await post(url: url, body: bodyData, headers: headers)

        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            throw NetworkError.decodingFailed
        }
    }

    // MARK: - HEAD Request

    /// 发起HEAD请求，获取资源信息但不下载
    public func head(url: URL, headers: [String: String]? = nil) async throws -> [String: String] {
        let method = HTTPMethod.head
        let httpHeaders = HTTPHeaders(mergedHeaders(with: headers))

        return try await withCheckedThrowingContinuation { continuation in
            activeSession.request(url, method: method, headers: httpHeaders)
                .validate(statusCode: 200..<300)
                .response { response in
                    if let error = response.error {
                        let networkError = self.mapError(error, response: response.response)
                        continuation.resume(throwing: networkError)
                        return
                    }

                    var headerFields: [String: String] = [:]
                    response.response?.allHeaderFields.forEach { key, value in
                        if let keyString = key as? String, let valueString = value as? String {
                            headerFields[keyString] = valueString
                        }
                    }

                    continuation.resume(returning: headerFields)
                }
        }
    }

    /// 获取文件大小
    public func getFileSize(url: URL) async throws -> Int64? {
        let headers = try await head(url: url)

        if let contentLength = headers["Content-Length"], let size = Int64(contentLength) {
            return size
        }

        return nil
    }

    // MARK: - Configuration

    /// 设置超时时间
    public func setTimeout(request: TimeInterval = 30, resource: TimeInterval = 300) {
        requestTimeout = request
        resourceTimeout = resource

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.httpMaximumConnectionsPerHost = maxConnectionsPerHost

        if !isMockMode {
            session.sessionConfiguration.httpMaximumConnectionsPerHost = maxConnectionsPerHost
        }
    }

    /// 设置最大连接数
    public func setMaxConnectionsPerHost(_ count: Int) {
        maxConnectionsPerHost = count
        session.sessionConfiguration.httpMaximumConnectionsPerHost = count
    }

    // MARK: - Private Methods

    private func mapError(_ error: AFError, response: HTTPURLResponse?) -> NetworkError {
        if let statusCode = response?.statusCode, !(200..<300).contains(statusCode) {
            return .serverError(statusCode: statusCode)
        }

        if let urlError = error.underlyingError as? URLError {
            switch urlError.code {
            case .badURL:
                return .invalidURL
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError(underlying: urlError)
            default:
                return .networkError(underlying: urlError)
            }
        }

        return error.toNetworkError()
    }

    private func mergedHeaders(with customHeaders: [String: String]?) -> [String: String] {
        var headers = customHeaders ?? [:]
        let userAgent = SettingsManager.shared.currentUserAgent
        if !userAgent.isEmpty {
            headers["User-Agent"] = userAgent
        }
        return headers
    }

    // MARK: - Mock Support for Testing

    private var activeSession: Session {
        return mockSession ?? session
    }

    /// 设置 mock session（仅用于测试）
    public func setMockSession(_ session: Session) {
        mockSession = session
        isMockMode = true
    }

    /// 清除 mock session（仅用于测试）
    public func clearMockSession() {
        mockSession = nil
        isMockMode = false
    }
}
