////
////  TSMergerTests.swift
////  DownloadManagerTests
////
////  Created by ace wei on 2026/6/1.
////
//
//import XCTest
//@testable import DownloadManager
//
//final class TSMergerTests: XCTestCase {
//
//    var merger: TSMerger!
//    var tempDirectory: URL!
//    var outputDirectory: URL!
//
//    override func setUp() {
//        super.setUp()
//        merger = TSMerger()
//
//        let tempDir = FileManager.default.temporaryDirectory
//        tempDirectory = tempDir.appendingPathComponent("TSMergerTests_\(UUID().uuidString)", isDirectory: true)
//        outputDirectory = tempDir.appendingPathComponent("TSMergerOutput_\(UUID().uuidString)", isDirectory: true)
//
//        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
//        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
//    }
//
//    override func tearDown() {
//        merger = nil
//
//        try? FileManager.default.removeItem(at: tempDirectory)
//        try? FileManager.default.removeItem(at: outputDirectory)
//
//        super.tearDown()
//    }
//
//    // MARK: - File Not Found Tests
//
//    func testMergeWithMissingSegmentFile() async throws {
//        let task = createMockTask(segmentCount: 3)
//
//        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory.path))
//
//        let outputURL = outputDirectory.appendingPathComponent("output.mp4")
//
//        do {
//            try await merger.merge(
//                segments: createMockSegments(count: 3),
//                task: task,
//                outputURL: outputURL
//            )
//            XCTFail("Expected TSMergerError.fileNotFound")
//        } catch let error as TSMergerError {
//            XCTAssertEqual(error, .fileNotFound)
//        }
//    }
//
//    // MARK: - Normal Merge Tests
//
//    func testMergeEmptySegments() async throws {
//        let task = createMockTask(segmentCount: 0)
//        let outputURL = outputDirectory.appendingPathComponent("output.mp4")
//
//        let segments = createMockSegments(count: 0)
//
//        try await merger.merge(
//            segments: segments,
//            task: task,
//            outputURL: outputURL
//        )
//
//        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
//    }
//
//    func testMergeSingleSegment() async throws {
//        let task = createMockTask(segmentCount: 1)
//
//        let segmentPath = task.tempSegmentPath(for: 0)
//        try createMockTSFile(at: segmentPath, size: 1024)
//
//        let outputURL = outputDirectory.appendingPathComponent("output.mp4")
//
//        var progressCalled = false
//        try await merger.merge(
//            segments: createMockSegments(count: 1),
//            task: task,
//            outputURL: outputURL
//        ) { progress in
//            progressCalled = true
//            XCTAssertGreaterThanOrEqual(progress, 0)
//        }
//
//        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
//    }
//
//    // MARK: - Progress Handler Tests
//
//    func testMergeWithProgressCallback() async throws {
//        let task = createMockTask(segmentCount: 3)
//
//        for i in 0..<3 {
//            let segmentPath = task.tempSegmentPath(for: i)
//            try createMockTSFile(at: segmentPath, size: 512)
//        }
//
//        let outputURL = outputDirectory.appendingPathComponent("output.mp4")
//
//        var progressValues: [Double] = []
//        try await merger.merge(
//            segments: createMockSegments(count: 3),
//            task: task,
//            outputURL: outputURL
//        ) { progress in
//            progressValues.append(progress)
//        }
//
//        XCTAssertFalse(progressValues.isEmpty)
//        XCTAssertEqual(progressValues.last, 1.0)
//    }
//
//    // MARK: - Cancel Tests
//
//    func testCancelDuringMerge() async throws {
//        let task = createMockTask(segmentCount: 5)
//
//        for i in 0..<5 {
//            let segmentPath = task.tempSegmentPath(for: i)
//            try createMockTSFile(at: segmentPath, size: 1024)
//        }
//
//        let outputURL = outputDirectory.appendingPathComponent("output.mp4")
//
//        merger.cancel()
//
//        do {
//            try await merger.merge(
//                segments: createMockSegments(count: 5),
//                task: task,
//                outputURL: outputURL
//            )
//        } catch let error as TSMergerError {
//            XCTAssertEqual(error, .cancelled)
//        }
//    }
//
//    // MARK: - Encrypted Segment Tests
//
//    func testMergeWithEncryptedSegments() async throws {
//        let segments = [
//            MediaSegment(
//                sequenceNumber: 0,
//                url: URL(string: "https://example.com/seg0.ts")!,
//                duration: 10.0,
//                encryptionMethod: .aes128,
//                encryptionKeyURI: URL(string: "https://example.com/key.bin"),
//                initializationVector: "0x12345678901234567890123456789012"
//            ),
//            MediaSegment(
//                sequenceNumber: 1,
//                url: URL(string: "https://example.com/seg1.ts")!,
//                duration: 10.0,
//                encryptionMethod: .aes128,
//                encryptionKeyURI: URL(string: "https://example.com/key.bin"),
//                initializationVector: "0x12345678901234567890123456789013"
//            )
//        ]
//
//        let task = createMockTask(segmentCount: 2)
//
//        for i in 0..<2 {
//            let segmentPath = task.tempSegmentPath(for: i)
//            try createMockTSFile(at: segmentPath, size: 512)
//        }
//
//        let outputURL = outputDirectory.appendingPathComponent("encrypted_output.mp4")
//
//        try await merger.merge(
//            segments: segments,
//            task: task,
//            outputURL: outputURL
//        )
//
//        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
//    }
//
//    // MARK: - Exception Handling Tests
//
//    func testMergeWithInvalidOutputDirectory() async throws {
//        let task = createMockTask(segmentCount: 1)
//
//        let segmentPath = task.tempSegmentPath(for: 0)
//        try createMockTSFile(at: segmentPath, size: 1024)
//
//        let invalidOutputURL = URL(fileURLWithPath: "/root/invalid/output.mp4")
//
//        do {
//            try await merger.merge(
//                segments: createMockSegments(count: 1),
//                task: task,
//                outputURL: invalidOutputURL
//            )
//            XCTFail("Expected error when writing to invalid path")
//        } catch {
//            XCTAssertTrue(error is TSMergerError || error is CocoaError)
//        }
//    }
//
//    func testMergeWithPartiallyMissingSegments() async throws {
//        let task = createMockTask(segmentCount: 3)
//
//        try createMockTSFile(at: task.tempSegmentPath(for: 0), size: 512)
//        try createMockTSFile(at: task.tempSegmentPath(for: 2), size: 512)
//
//        let outputURL = outputDirectory.appendingPathComponent("output.mp4")
//
//        do {
//            try await merger.merge(
//                segments: createMockSegments(count: 3),
//                task: task,
//                outputURL: outputURL
//            )
//            XCTFail("Expected TSMergerError.fileNotFound")
//        } catch let error as TSMergerError {
//            XCTAssertEqual(error, .fileNotFound)
//        }
//    }
//
//    // MARK: - Helper Methods
//
//    private func createMockTask(segmentCount: Int) -> M3U8DownloadTask {
//        let task = M3U8DownloadTask(
//            url: URL(string: "https://example.com/test.m3u8")!,
//            savePath: tempDirectory
//        )
//
//        task.tempDirectory = tempDirectory
//
//        return task
//    }
//
//    private func createMockSegments(count: Int) -> [MediaSegment] {
//        return (0..<count).map { index in
//            MediaSegment(
//                sequenceNumber: index,
//                url: URL(string: "https://example.com/segment\(index).ts")!,
//                duration: 10.0,
//                encryptionMethod: .none
//            )
//        }
//    }
//
//    private func createMockTSFile(at url: URL, size: Int) throws {
//        let data = Data(repeating: 0, count: size)
//        try data.write(to: url)
//    }
//}
