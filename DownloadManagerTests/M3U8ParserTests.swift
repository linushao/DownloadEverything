////
////  M3U8ParserTests.swift
////  DownloadManagerTests
////
////  Created by ace wei on 2026/6/1.
////
//
//import XCTest
//
//@testable import DownloadManager
//
//final class M3U8ParserTests: XCTestCase {
//
//    var parser: M3U8Parser!
//    fileprivate var mockNetworkService: MockNetworkService!
//
//    override func setUp() {
//        super.setUp()
//        mockNetworkService = MockNetworkService()
//        parser = M3U8Parser(networkService: mockNetworkService)
//    }
//
//    override func tearDown() {
//        parser = nil
//        mockNetworkService = nil
//        super.tearDown()
//    }
//
//    // MARK: - Normal M3U8 Parsing Tests
//
//    func testParseSimpleM3U8() throws {
//        let m3u8Content = """
//            #EXTM3U
//            #EXT-X-VERSION:3
//            #EXT-X-TARGETDURATION:10
//            #EXT-X-MEDIA-SEQUENCE:0
//            #EXTINF:9.9,
//            segment0.ts
//            #EXTINF:9.9,
//            segment1.ts
//            #EXTINF:9.9,
//            segment2.ts
//            #EXT-X-ENDLIST
//            """
//
//        let baseURL = URL(string: "https://example.com/playlist.m3u8")!
//        let playlist = try parser.parse(content: m3u8Content, baseURL: baseURL)
//
//        XCTAssertEqual(playlist.type, .media)
//        XCTAssertEqual(playlist.segments.count, 3)
//        XCTAssertEqual(playlist.segments[0].sequenceNumber, 0)
//        XCTAssertEqual(playlist.segments[0].url.absoluteString, "https://example.com/segment0.ts")
//        XCTAssertEqual(playlist.segments[0].duration, 9.9)
//        XCTAssertEqual(playlist.segments[1].sequenceNumber, 1)
//        XCTAssertEqual(playlist.segments[2].sequenceNumber, 2)
//        XCTAssertFalse(playlist.isLive)
//        XCTAssertEqual(playlist.version, 3)
//        XCTAssertEqual(playlist.targetDuration, 10)
//    }
//
//    func testParseM3U8WithNoEXTINF() throws {
//        let m3u8Content = """
//            #EXTM3U
//            #EXT-X-VERSION:3
//            #EXT-X-TARGETDURATION:10
//            #EXT-X-MEDIA-SEQUENCE:0
//            segment0.ts
//            segment1.ts
//            segment2.ts
//            #EXT-X-ENDLIST
//            """
//
//        let baseURL = URL(string: "https://example.com/playlist.m3u8")!
//        let playlist = try parser.parse(content: m3u8Content, baseURL: baseURL)
//
//        XCTAssertEqual(playlist.type, .media)
//        XCTAssertEqual(playlist.segments.count, 3)
//        XCTAssertEqual(playlist.segments[0].duration, 0)
//    }
//
//    // MARK: - Variant Stream Parsing Tests
//
//    func testParseVariantStreamM3U8() throws {
//        let m3u8Content = """
//            #EXTM3U
//            #EXT-X-STREAM-INF:BANDWIDTH=1280000,RESOLUTION=720x480,CODECS="avc1.64001f"
//            low.m3u8
//            #EXT-X-STREAM-INF:BANDWIDTH=2560000,RESOLUTION=1280x720,CODECS="avc1.64001f"
//            mid.m3u8
//            #EXT-X-STREAM-INF:BANDWIDTH=7680000,RESOLUTION=1920x1080,CODECS="avc1.64001f"
//            high.m3u8
//            """
//
//        let baseURL = URL(string: "https://example.com/master.m3u8")!
//        let playlist = try parser.parse(content: m3u8Content, baseURL: baseURL)
//
//        XCTAssertEqual(playlist.type, .master)
//        XCTAssertEqual(playlist.variants.count, 3)
//        XCTAssertEqual(playlist.variants[0].bandwidth, 1_280_000)
//        XCTAssertEqual(playlist.variants[0].resolution, "720x480")
//        XCTAssertEqual(playlist.variants[1].bandwidth, 2_560_000)
//        XCTAssertEqual(playlist.variants[2].bandwidth, 7_680_000)
//        XCTAssertEqual(playlist.segments.count, 0)
//    }
//
//    func testParseVariantStreamWithRelativeURL() throws {
//        let m3u8Content = """
//            #EXTM3U
//            #EXT-X-STREAM-INF:BANDWIDTH=1280000
//            path/to/low.m3u8
//            #EXT-X-STREAM-INF:BANDWIDTH=2560000
//            path/to/high.m3u8
//            """
//
//        let baseURL = URL(string: "https://example.com/folder/master.m3u8")!
//        let playlist = try parser.parse(content: m3u8Content, baseURL: baseURL)
//
//        XCTAssertEqual(playlist.type, .master)
//        XCTAssertEqual(playlist.variants.count, 2)
//        XCTAssertEqual(
//            playlist.variants[0].url.absoluteString, "https://example.com/folder/path/to/low.m3u8")
//        XCTAssertEqual(
//            playlist.variants[1].url.absoluteString, "https://example.com/folder/path/to/high.m3u8")
//    }
//
//    // MARK: - Invalid Format Tests
//
//    func testParseInvalidM3U8WithoutEXTM3U() {
//        let m3u8Content = """
//            #EXT-X-VERSION:3
//            #EXTINF:9.9,
//            segment0.ts
//            """
//
//        let baseURL = URL(string: "https://example.com/playlist.m3u8")!
//
//        XCTAssertThrowsError(try parser.parse(content: m3u8Content, baseURL: baseURL)) { error in
//            XCTAssertEqual(error as? M3U8ParserError, .invalidFormat)
//        }
//    }
//
//    func testParseEmptyM3U8() {
//        let m3u8Content = ""
//
//        let baseURL = URL(string: "https://example.com/playlist.m3u8")!
//
//        XCTAssertThrowsError(try parser.parse(content: m3u8Content, baseURL: baseURL)) { error in
//            XCTAssertEqual(error as? M3U8ParserError, .emptyPlaylist)
//        }
//    }
//
//    func testParseM3U8WithOnlyWhitespace() {
//        let m3u8Content = "   \n   \n   "
//
//        let baseURL = URL(string: "https://example.com/playlist.m3u8")!
//
//        XCTAssertThrowsError(try parser.parse(content: m3u8Content, baseURL: baseURL)) { error in
//            XCTAssertEqual(error as? M3U8ParserError, .emptyPlaylist)
//        }
//    }
//
//    func testParseM3U8WithOnlyComments() {
//        let m3u8Content = """
//            #EXTM3U
//            # This is a comment
//            # Another comment
//            """
//
//        let baseURL = URL(string: "https://example.com/playlist.m3u8")!
//
//        XCTAssertThrowsError(try parser.parse(content: m3u8Content, baseURL: baseURL)) { error in
//            XCTAssertEqual(error as? M3U8ParserError, .emptyPlaylist)
//        }
//    }
//
//    // MARK: - Relative Path Tests
//
//    func testParseRelativePathWithLeadingSlash() throws {
//        let m3u8Content = """
//            #EXTM3U
//            #EXT-X-VERSION:3
//            #EXT-X-TARGETDURATION:10
//            #EXTINF:9.9,
//            /absolute/path/segment0.ts
//            #EXTINF:9.9,
//            segment1.ts
//            #EXT-X-ENDLIST
//            """
//
//        let baseURL = URL(string: "https://example.com/playlist.m3u8")!
//        let playlist = try parser.parse(content: m3u8Content, baseURL: baseURL)
//
//        XCTAssertEqual(playlist.segments.count, 2)
//        XCTAssertEqual(
//            playlist.segments[0].url.absoluteString, "https://example.com/absolute/path/segment0.ts"
//        )
//        XCTAssertEqual(playlist.segments[1].url.absoluteString, "https://example.com/segment1.ts")
//    }
//
//    func testParseRelativePathWithoutLeadingSlash() throws {
//        let m3u8Content = """
//            #EXTM3U
//            #EXT-X-VERSION:3
//            #EXT-X-TARGETDURATION:10
//            #EXTINF:9.9,
//            segment0.ts
//            #EXTINF:9.9,
//            subdir/segment1.ts
//            #EXT-X-ENDLIST
//            """
//
//        let baseURL = URL(string: "https://example.com/folder/playlist.m3u8")!
//        let playlist = try parser.parse(content: m3u8Content, baseURL: baseURL)
//
//        XCTAssertEqual(playlist.segments.count, 2)
//        XCTAssertEqual(
//            playlist.segments[0].url.absoluteString, "https://example.com/folder/segment0.ts")
//        XCTAssertEqual(
//            playlist.segments[1].url.absoluteString, "https://example.com/folder/subdir/segment1.ts"
//        )
//    }
//
//    func testParseAbsoluteURL() throws {
//        let m3u8Content = """
//            #EXTM3U
//            #EXT-X-VERSION:3
//            #EXT-X-TARGETDURATION:10
//            #EXTINF:9.9,
//            https://cdn.example.com/segment0.ts
//            #EXTINF:9.9,
//            http://cdn2.example.com/segment1.ts
//            #EXT-X-ENDLIST
//            """
//
//        let baseURL = URL(string: "https://example.com/playlist.m3u8")!
//        let playlist = try parser.parse(content: m3u8Content, baseURL: baseURL)
//
//        XCTAssertEqual(playlist.segments.count, 2)
//        XCTAssertEqual(
//            playlist.segments[0].url.absoluteString, "https://cdn.example.com/segment0.ts")
//        XCTAssertEqual(
//            playlist.segments[1].url.absoluteString, "http://cdn2.example.com/segment1.ts")
//    }
//
//    // MARK: - AES-128 Encryption Tests
//
//    func testParseAES128EncryptedM3U8() throws {
//        let m3u8Content = """
//            #EXTM3U
//            #EXT-X-VERSION:3
//            #EXT-X-TARGETDURATION:10
//            #EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key.bin",IV=0x12345678901234567890123456789012
//            #EXTINF:9.9,
//            encrypted0.ts
//            #EXTINF:9.9,
//            encrypted1.ts
//            #EXT-X-KEY:METHOD=NONE
//            #EXTINF:9.9,
//            segment2.ts
//            #EXT-X-ENDLIST
//            """
//
//        let baseURL = URL(string: "https://example.com/playlist.m3u8")!
//        let playlist = try parser.parse(content: m3u8Content, baseURL: baseURL)
//
//        XCTAssertEqual(playlist.type, .media)
//        XCTAssertEqual(playlist.segments.count, 3)
//
//        XCTAssertEqual(playlist.segments[0].encryptionMethod, .aes128)
//        XCTAssertEqual(
//            playlist.segments[0].encryptionKeyURI?.absoluteString, "https://example.com/key.bin")
//        XCTAssertEqual(
//            playlist.segments[0].initializationVector, "0x12345678901234567890123456789012")
//
//        XCTAssertEqual(playlist.segments[1].encryptionMethod, .aes128)
//        XCTAssertEqual(playlist.segments[2].encryptionMethod, .none)
//    }
//
//    // MARK: - Live Stream Tests
//
//    func testParseLiveStreamWithoutENDLIST() throws {
//        let m3u8Content = """
//            #EXTM3U
//            #EXT-X-VERSION:3
//            #EXT-X-TARGETDURATION:10
//            #EXT-X-MEDIA-SEQUENCE:100
//            #EXTINF:9.9,
//            segment100.ts
//            #EXTINF:9.9,
//            segment101.ts
//            """
//
//        let baseURL = URL(string: "https://example.com/live.m3u8")!
//        let playlist = try parser.parse(content: m3u8Content, baseURL: baseURL)
//
//        XCTAssertEqual(playlist.type, .media)
//        XCTAssertTrue(playlist.isLive)
//        XCTAssertEqual(playlist.segments.count, 2)
//        XCTAssertEqual(playlist.segments[0].sequenceNumber, 100)
//    }
//
//    // MARK: - Media Sequence Tests
//
//    func testParseWithMediaSequence() throws {
//        let m3u8Content = """
//            #EXTM3U
//            #EXT-X-VERSION:3
//            #EXT-X-TARGETDURATION:10
//            #EXT-X-MEDIA-SEQUENCE:5000
//            #EXTINF:9.9,
//            segment5000.ts
//            #EXTINF:9.9,
//            segment5001.ts
//            #EXT-X-ENDLIST
//            """
//
//        let baseURL = URL(string: "https://example.com/playlist.m3u8")!
//        let playlist = try parser.parse(content: m3u8Content, baseURL: baseURL)
//
//        XCTAssertEqual(playlist.segments.count, 2)
//        XCTAssertEqual(playlist.segments[0].sequenceNumber, 5000)
//        XCTAssertEqual(playlist.segments[1].sequenceNumber, 5001)
//    }
//
//    // MARK: - Title Tests
//
//    func testParseEXTINFWithTitle() throws {
//        let m3u8Content = """
//            #EXTM3U
//            #EXT-X-VERSION:3
//            #EXT-X-TARGETDURATION:10
//            #EXTINF:9.9,Movie Title 1
//            segment0.ts
//            #EXTINF:10.0,Movie Title 2
//            segment1.ts
//            #EXTINF:9.5,
//            segment2.ts
//            #EXT-X-ENDLIST
//            """
//
//        let baseURL = URL(string: "https://example.com/playlist.m3u8")!
//        let playlist = try parser.parse(content: m3u8Content, baseURL: baseURL)
//
//        XCTAssertEqual(playlist.segments.count, 3)
//        XCTAssertEqual(playlist.segments[0].title, "Movie Title 1")
//        XCTAssertEqual(playlist.segments[1].title, "Movie Title 2")
//        XCTAssertNil(playlist.segments[2].title)
//    }
//
//    // MARK: - Suggest FileName Tests
//
//    func testSuggestFileNameFromM3U8URL() {
//        let playlist = M3U8Playlist(
//            url: URL(string: "https://example.com/video/playlist.m3u8")!,
//            type: .media,
//            variants: [],
//            segments: [],
//            totalDuration: 0
//        )
//
//        let fileName = parser.suggestFileName(for: playlist)
//        XCTAssertEqual(fileName, "playlist.mp4")
//    }
//
//    func testSuggestFileNameFromURLWithoutExtension() {
//        let playlist = M3U8Playlist(
//            url: URL(string: "https://example.com/video")!,
//            type: .media,
//            variants: [],
//            segments: [],
//            totalDuration: 0
//        )
//
//        let fileName = parser.suggestFileName(for: playlist)
//        XCTAssertEqual(fileName, "video.mp4")
//    }
//
//    func testSuggestFileNameFromMasterPlaylist() {
//        let playlist = M3U8Playlist(
//            url: URL(string: "https://example.com/master.m3u8")!,
//            type: .master,
//            variants: [],
//            segments: [],
//            totalDuration: 0
//        )
//
//        let fileName = parser.suggestFileName(for: playlist)
//        XCTAssertEqual(fileName, "master.mp4")
//    }
//}
//
//// MARK: - Mock Network Service
//
//private class MockNetworkService: NetworkServiceProtocol {
//    var mockData: Data?
//    var mockError: Error?
//
//    func get(url: URL, headers: [String: String]?) async throws -> Data {
//        if let error = mockError {
//            throw error
//        }
//        guard let data = mockData else {
//            throw NSError(domain: "MockNetworkService", code: -1, userInfo: nil)
//        }
//        return data
//    }
//}
