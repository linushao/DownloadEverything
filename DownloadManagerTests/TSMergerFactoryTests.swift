//
//  TSMergerFactoryTests.swift
//  DownloadManagerTests
//
//  Created by TDD Assistant on 2026/6/2.
//

import XCTest
@testable import DownloadManager

final class TSMergerFactoryTests: XCTestCase {

    // MARK: - Factory Tests

    func testFactoryCreatesDefaultMerger() {
        let merger = TSMergerFactory.makeDefault()
        XCTAssertNotNil(merger)
    }

    func testFactoryCreatesFFmpegMerger() {
        let merger = TSMergerFactory.makeFFmpeg()
        XCTAssertNotNil(merger)
        XCTAssertTrue(merger is TSMerger)
    }

    func testFactoryCreatesVideoToolboxMerger() {
        let merger = TSMergerFactory.makeVideoToolbox()
        XCTAssertNotNil(merger)
    }
}
