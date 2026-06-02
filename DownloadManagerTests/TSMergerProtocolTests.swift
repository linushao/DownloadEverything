//
//  TSMergerProtocolTests.swift
//  DownloadManagerTests
//
//  Created by TDD Assistant on 2026/6/2.
//

import XCTest
@testable import DownloadManager

final class TSMergerProtocolTests: XCTestCase {

    // MARK: - Protocol Definition Tests

    func testTSMergerProtocolExistence() {
        // This test will fail at compile time if TSMergerProtocol is not defined
        // We'll use a dummy struct to verify conformance
        struct DummyMerger: TSMergerProtocol {
            func merge(segments: [MediaSegment], task: M3U8DownloadTask, outputURL: URL, progressHandler: ((Double) -> Void)?) async throws { }
            func cancel() { }
        }

        let _ = DummyMerger()
        XCTAssertTrue(true, "TSMergerProtocol is defined")
    }

    func testTSMergerProtocolHasMergeMethod() {
        let merger: TSMergerProtocol = MockTSMerger()

        // Verify we can call merge()
        XCTAssertNotNil(merger)
    }

    func testTSMergerProtocolHasCancelMethod() {
        let merger: TSMergerProtocol = MockTSMerger()

        // Verify we can call cancel()
        merger.cancel()
        XCTAssertTrue(true, "cancel() called successfully")
    }
}

// MARK: - Mock TSMerger

private class MockTSMerger: TSMergerProtocol {
    private(set) var cancelCalled = false

    func merge(segments: [MediaSegment], task: M3U8DownloadTask, outputURL: URL, progressHandler: ((Double) -> Void)?) async throws { }

    func cancel() {
        cancelCalled = true
    }
}
