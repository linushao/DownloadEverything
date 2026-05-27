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
}

/// 网络服务类，基于URLSession封装网络请求
public final class NetworkService {

    // MARK: - Singleton

    public static let shared = NetworkService()

    // MARK: - Properties

    private let session: URLSession
    private let sessionConfiguration: URLSessionConfiguration

    // MARK: - Initialization

    private init() {
        sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = 30
        sessionConfiguration.timeoutIntervalForResource = 300
        sessionConfiguration.httpMaximumConnectionsPerHost = 4

        session = URLSession(configuration: sessionConfiguration)
    }

    // MARK: - GET Request

    /// 发起GET请求
    public func get(url: URL, headers: [String: String]? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.networkError(underlying: NSError(domain: "NetworkService", code: -1))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    /// 发起GET请求并解码为指定类型
    public func get<T: Decodable>(url: URL, headers: [String: String]? = nil) async throws -> T {
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
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.networkError(underlying: NSError(domain: "NetworkService", code: -1))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    /// 发起POST请求并解码为指定类型
    public func post<T: Decodable, B: Encodable>(url: URL, body: B, headers: [String: String]? = nil) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)

        let data = try await post(url: url, body: bodyData, headers: headers)

        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            throw NetworkError.decodingFailed
        }
    }

    // MARK: - Download with Resume Support

    /// 创建可恢复的下载任务
    public func createResumableDownloadTask(url: URL) -> URLSessionDownloadTask {
        return session.downloadTask(with: url)
    }

    /// 使用resumeData创建下载任务
    public func createResumableDownloadTask(resumeData: Data) -> URLSessionDownloadTask {
        return session.downloadTask(withResumeData: resumeData)
    }

    // MARK: - HEAD Request

    /// 发起HEAD请求，获取资源信息但不下载
    public func head(url: URL, headers: [String: String]? = nil) async throws -> [String: String] {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.networkError(underlying: NSError(domain: "NetworkService", code: -1))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }

        var headerFields: [String: String] = [:]
        httpResponse.allHeaderFields.forEach { key, value in
            if let keyString = key as? String, let valueString = value as? String {
                headerFields[keyString] = valueString
            }
        }

        return headerFields
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
        sessionConfiguration.timeoutIntervalForRequest = request
        sessionConfiguration.timeoutIntervalForResource = resource
    }

    /// 设置最大连接数
    public func setMaxConnectionsPerHost(_ count: Int) {
        sessionConfiguration.httpMaximumConnectionsPerHost = count
    }
}
