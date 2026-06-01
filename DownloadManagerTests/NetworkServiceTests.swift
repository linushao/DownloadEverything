//
//  NetworkServiceTests.swift
//  DownloadManagerTests
//
//  Created by ace wei on 2026/5/28.
//

import Alamofire
import XCTest

@testable import DownloadManager

final class NetworkServiceTests: XCTestCase {

    var networkService: NetworkService!
    var mockSession: Session!

    override func setUp() {
        super.setUp()

        MockURLProtocol.requestHandler = nil
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        mockSession = Session(configuration: configuration)

        networkService = NetworkService.shared
        networkService.setMockSession(mockSession)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        networkService.clearMockSession()
        networkService = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testTimeoutConfiguration() {
        networkService.setTimeout(request: 10, resource: 60)
    }

    func testMaxConnectionsConfiguration() {
        networkService.setMaxConnectionsPerHost(8)
    }

    // MARK: - NetworkError Tests

    func testNetworkErrorDescriptions() {
        let invalidURLError = NetworkError.invalidURL
        XCTAssertEqual(invalidURLError.errorDescription, "无效的URL")

        let noDataError = NetworkError.noData
        XCTAssertEqual(noDataError.errorDescription, "服务器未返回数据")

        let decodingFailedError = NetworkError.decodingFailed
        XCTAssertEqual(decodingFailedError.errorDescription, "数据解析失败")

        let serverError = NetworkError.serverError(statusCode: 500)
        XCTAssertEqual(serverError.errorDescription, "服务器错误: 500")

        let underlyingError = NSError(
            domain: "Test",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "The operation couldn't be completed. (Test error -1.)"
            ]
        )
        let networkError = NetworkError.networkError(underlying: underlyingError)
        XCTAssertEqual(
            networkError.errorDescription,
            "网络错误: The operation couldn't be completed. (Test error -1.)")
    }

    // MARK: - HEAD Request Tests

    func testHeadRequestSuccess() async throws {
        let testURL = URL(string: "https://example.com/test")!

        MockURLProtocol.requestHandler = { request in
            guard request.httpMethod == "HEAD" else {
                throw NetworkError.networkError(underlying: NSError(domain: "Test", code: -1))
            }
            let response = HTTPURLResponse(
                url: testURL, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!
            return (response, Data())
        }

        let headers = try await networkService.head(url: testURL)
        XCTAssertEqual(headers["Content-Type"], "application/json")
    }

    func testHeadRequestServerError() async {
        let testURL = URL(string: "https://example.com/test")!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: testURL, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await networkService.head(url: testURL)
            XCTFail("Expected error")
        } catch NetworkError.serverError(let statusCode) {
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Get File Size Tests

    func testGetFileSizeSuccess() async throws {
        let testURL = URL(string: "https://example.com/image.png")!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: testURL, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Length": "1024"])!
            return (response, Data())
        }

        let size = try await networkService.getFileSize(url: testURL)
        XCTAssertEqual(size, 1024)
    }

    func testGetFileSizeNotFound() async {
        let testURL = URL(string: "https://example.com/notfound.png")!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: testURL, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await networkService.getFileSize(url: testURL)
            XCTFail("Expected error")
        } catch NetworkError.serverError(let statusCode) {
            XCTAssertEqual(statusCode, 404)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Data Request Tests

    func testGetRequestSuccess() async throws {
        let testURL = URL(string: "https://example.com/get")!
        let responseData = "{\"status\":\"success\"}".data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseData)
        }

        let data = try await networkService.get(url: testURL)
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(String(data: data, encoding: .utf8), "{\"status\":\"success\"}")
    }

    func testGetRequestWithHeaders() async throws {
        let testURL = URL(string: "https://example.com/headers")!
        let responseData = "{\"headers\":{\"X-Custom-Header\":\"test-value\"}}".data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom-Header"), "test-value")
            let response = HTTPURLResponse(
                url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseData)
        }

        let headers = ["X-Custom-Header": "test-value"]
        let data = try await networkService.get(url: testURL, headers: headers)
        XCTAssertFalse(data.isEmpty)
    }

    func testGetRequestServerError() async {
        let testURL = URL(string: "https://example.com/error")!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: testURL, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await networkService.get(url: testURL)
            XCTFail("Expected server error")
        } catch NetworkError.serverError(let statusCode) {
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetRequestNotFound() async {
        let testURL = URL(string: "https://example.com/notfound")!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: testURL, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await networkService.get(url: testURL)
            XCTFail("Expected not found error")
        } catch NetworkError.serverError(let statusCode) {
            XCTAssertEqual(statusCode, 404)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - POST Request Tests

    func testPostRequestSuccess() async throws {
        let testURL = URL(string: "https://example.com/post")!
        let responseData = "{\"result\":\"ok\"}".data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let response = HTTPURLResponse(
                url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseData)
        }

        let body = ["key": "value"]
        let bodyData = try JSONEncoder().encode(body)

        let data = try await networkService.post(url: testURL, body: bodyData)
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(String(data: data, encoding: .utf8), "{\"result\":\"ok\"}")
    }

    func testPostRequestWithEmptyBody() async throws {
        let testURL = URL(string: "https://example.com/post")!
        let responseData = "{\"result\":\"ok\"}".data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            let response = HTTPURLResponse(
                url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseData)
        }

        let data = try await networkService.post(url: testURL, body: nil)
        XCTAssertFalse(data.isEmpty)
    }

    // MARK: - Decodable Request Tests

    func testGetDecodableSuccess() async throws {
        let testURL = URL(string: "https://example.com/get")!
        let responseData = """
            {
                "args": {},
                "headers": {"Accept": "application/json"},
                "origin": "127.0.0.1",
                "url": "https://example.com/get"
            }
            """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseData)
        }

        struct Response: Decodable {
            let args: [String: String]
            let headers: [String: String]
            let origin: String
            let url: String
        }

        let response = try await networkService.get(Response.self, url: testURL)
        XCTAssertEqual(response.origin, "127.0.0.1")
        XCTAssertEqual(response.url, "https://example.com/get")
    }

    func testGetDecodableFailure() async {
        let testURL = URL(string: "https://example.com/image")!
        let responseData = "not valid json".data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseData)
        }

        struct Response: Decodable {
            let key: String
        }

        do {
            _ = try await networkService.get(Response.self, url: testURL)
            XCTFail("Expected decoding failure")
        } catch NetworkError.decodingFailed {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Mock URL Protocol

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("MockURLProtocol requestHandler is not set")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch let error as NetworkError {
            client?.urlProtocol(self, didFailWithError: error.asNSError)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
    }
}
