//
//  VideoToolboxTSMergerTests.swift
//  DownloadManagerTests
//
//  Created by TDD Assistant on 2026/6/2.
//

import XCTest
@testable import DownloadManager

final class VideoToolboxTSMergerTests: XCTestCase {

    var sut: VideoToolboxTSMerger!
    var tempDirectory: URL!
    var outputDirectory: URL!

    override func setUp() {
        super.setUp()
        sut = VideoToolboxTSMerger()

        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent("VideoToolboxTSMergerTests_\(UUID().uuidString)", isDirectory: true)
        outputDirectory = tempDir.appendingPathComponent("VideoToolboxTSMergerOutput_\(UUID().uuidString)", isDirectory: true)

        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        sut = nil

        try? FileManager.default.removeItem(at: tempDirectory)
        try? FileManager.default.removeItem(at: outputDirectory)

        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut)
    }

    func testConformsToTSMergerProtocol() {
        let merger: TSMergerProtocol = VideoToolboxTSMerger()
        XCTAssertNotNil(merger)
    }

    // MARK: - Cancel Tests

    func testCancelMethodExists() {
        sut.cancel()
        // 测试不会崩溃即可
        XCTAssertTrue(true)
    }

    // MARK: - Factory Tests

    func testFactoryCreatesVideoToolboxMerger() {
        let merger = TSMergerFactory.makeVideoToolbox()
        XCTAssertTrue(merger is VideoToolboxTSMerger)
    }

    // MARK: - Helper Methods

    private func createMockTask(segmentCount: Int) -> M3U8DownloadTask {
        let task = M3U8DownloadTask(
            url: URL(string: "https://example.com/test.m3u8")!,
            savePath: tempDirectory
        )

        task.tempDirectory = tempDirectory

        return task
    }

    private func createMockSegments(count: Int) -> [MediaSegment] {
        return (0..<count).map { index in
            MediaSegment(
                sequenceNumber: index,
                url: URL(string: "https://example.com/segment\(index).ts")!,
                duration: 10.0,
                encryptionMethod: .none
            )
        }
    }
}
