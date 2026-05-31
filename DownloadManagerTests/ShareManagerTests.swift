//
//  ShareManagerTests.swift
//  DownloadManagerTests
//
//  Created by ace wei on 2026/5/28.
//

import XCTest

@testable import DownloadManager

final class ShareManagerTests: XCTestCase {

    var shareManager: ShareManager!

    override func setUp() {
        super.setUp()
        shareManager = ShareManager.shared

        // 确保测试开始前没有残留数据
        let allShares = shareManager.getAllShares()
        allShares.forEach { shareManager.deleteShare(shareId: $0.shareId) }

        // 等待清理完成
        let expectation = XCTestExpectation(description: "Cleanup before test")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    override func tearDown() {
        // 清理所有分享
        let allShares = shareManager.getAllShares()

        // 使用信号量等待所有删除操作完成
        let semaphore = DispatchSemaphore(value: 0)
        var deletedCount = 0

        for share in allShares {
            shareManager.deleteShare(shareId: share.shareId)
            deletedCount += 1
        }

        // 等待一小段时间让删除操作完成
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5.0)

        shareManager = nil
        super.tearDown()
    }

    // MARK: - Create Share Tests

    func testCreateShare() {
        let testPath = "/test/path/file.txt"
        let shareItem = shareManager.createShare(
            filePath: testPath,
            shareType: .file,
            permission: .readOnly
        )

        XCTAssertNotNil(shareItem)
        XCTAssertEqual(shareItem.filePath, testPath)
        XCTAssertEqual(shareItem.shareType, .file)
        XCTAssertEqual(shareItem.permission, .readOnly)
        XCTAssertNil(shareItem.expiresAt)
        XCTAssertFalse(shareItem.isExpired)
        XCTAssertTrue(shareItem.isValid)
    }

    func testCreateShareWithExpiration() {
        let testPath = "/test/path/file.txt"
        let shareItem = shareManager.createShareWithExpiration(
            filePath: testPath,
            shareType: .file,
            permission: .readWrite,
            days: 7
        )

        XCTAssertNotNil(shareItem)
        XCTAssertEqual(shareItem.filePath, testPath)
        XCTAssertEqual(shareItem.shareType, .file)
        XCTAssertEqual(shareItem.permission, .readWrite)
        XCTAssertNotNil(shareItem.expiresAt)
        XCTAssertFalse(shareItem.isExpired)
        XCTAssertTrue(shareItem.isValid)
    }

    // MARK: - Get Share Tests

    func testGetAllShares() {
        let share1 = shareManager.createShare(
            filePath: "/test/path/file1.txt",
            shareType: .file
        )
        let share2 = shareManager.createShare(
            filePath: "/test/path/file2.txt",
            shareType: .folder
        )

        // 等待异步创建完成
        let expectation = XCTestExpectation(description: "Create shares")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let allShares = shareManager.getAllShares()
        XCTAssertEqual(allShares.count, 2)
        XCTAssert(allShares.contains { $0.shareId == share1.shareId })
        XCTAssert(allShares.contains { $0.shareId == share2.shareId })
    }

    func testGetValidShares() {
        // 创建永不过期的分享
        let validShare = shareManager.createShare(
            filePath: "/test/path/valid.txt",
            shareType: .file
        )

        // 创建已过期的分享
        let expiredDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let expiredShare = shareManager.createShare(
            filePath: "/test/path/expired.txt",
            shareType: .file,
            expiresAt: expiredDate
        )

        let validShares = shareManager.getValidShares()
        XCTAssertEqual(validShares.count, 1)
        XCTAssertEqual(validShares.first?.shareId, validShare.shareId)
    }

    func testGetShareById() {
        let shareItem = shareManager.createShare(
            filePath: "/test/path/file.txt",
            shareType: .file
        )

        let retrievedShare = shareManager.getShare(shareId: shareItem.shareId)
        XCTAssertNotNil(retrievedShare)
        XCTAssertEqual(retrievedShare?.shareId, shareItem.shareId)
        XCTAssertEqual(retrievedShare?.filePath, shareItem.filePath)
    }

    func testGetShareByNonExistentId() {
        let nonExistentId = UUID()
        let result = shareManager.getShare(shareId: nonExistentId)
        XCTAssertNil(result)
    }

    // MARK: - Delete Share Tests

    func testDeleteShare() {
        let shareItem = shareManager.createShare(
            filePath: "/test/path/file.txt",
            shareType: .file
        )

        let result = shareManager.deleteShare(shareId: shareItem.shareId)
        XCTAssertTrue(result)

        let deletedShare = shareManager.getShare(shareId: shareItem.shareId)
        XCTAssertNil(deletedShare)
    }

    func testDeleteNonExistentShare() {
        let nonExistentId = UUID()
        let result = shareManager.deleteShare(shareId: nonExistentId)
        XCTAssertFalse(result)
    }

    // MARK: - Token Validation Tests

    func testValidateToken() {
        let shareItem = shareManager.createShare(
            filePath: "/test/path/file.txt",
            shareType: .file
        )

        let result = shareManager.validateToken(token: shareItem.accessToken)
        XCTAssertTrue(result)
    }

    func testValidateInvalidToken() {
        let result = shareManager.validateToken(token: "invalid-token-12345")
        XCTAssertFalse(result)
    }

    func testValidateExpiredToken() {
        let expiredDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let shareItem = shareManager.createShare(
            filePath: "/test/path/file.txt",
            shareType: .file,
            expiresAt: expiredDate
        )

        let result = shareManager.validateToken(token: shareItem.accessToken)
        XCTAssertFalse(result)
    }

    // MARK: - Get Share by Token Tests

    func testGetShareByToken() {
        let shareItem = shareManager.createShare(
            filePath: "/test/path/file.txt",
            shareType: .file
        )

        let retrievedShare = shareManager.getShare(byToken: shareItem.accessToken)
        XCTAssertNotNil(retrievedShare)
        XCTAssertEqual(retrievedShare?.shareId, shareItem.shareId)
    }

    func testGetShareByInvalidToken() {
        let result = shareManager.getShare(byToken: "invalid-token-12345")
        XCTAssertNil(result)
    }

    // MARK: - Share Link Tests

    func testGetShareLink() {
        let shareItem = shareManager.createShare(
            filePath: "/test/path/file.txt",
            shareType: .file
        )

        let link = shareManager.getShareLink(shareId: shareItem.shareId)
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.scheme, "downloadapp")
        XCTAssertEqual(link?.host, "share")
        XCTAssert(link?.path.contains(shareItem.accessToken) ?? false)
    }

    func testGetShareLinkForNonExistentShare() {
        let nonExistentId = UUID()
        let link = shareManager.getShareLink(shareId: nonExistentId)
        XCTAssertNil(link)
    }

    // MARK: - Clean Expired Shares Tests

    func testCleanExpiredShares() {
        // 创建过期分享
        let expiredDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        shareManager.createShare(
            filePath: "/test/path/expired1.txt",
            shareType: .file,
            expiresAt: expiredDate
        )
        shareManager.createShare(
            filePath: "/test/path/expired2.txt",
            shareType: .file,
            expiresAt: expiredDate
        )

        // 创建有效分享
        shareManager.createShare(
            filePath: "/test/path/valid.txt",
            shareType: .file
        )

        // 等待异步创建完成
        let createExpectation = XCTestExpectation(description: "Create shares")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            createExpectation.fulfill()
        }
        wait(for: [createExpectation], timeout: 3.0)

        // 清理过期分享
        shareManager.cleanExpiredShares()

        // 等待异步清理操作完成
        let cleanupExpectation = XCTestExpectation(description: "Cleanup expired shares")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 3.0)

        let remainingShares = shareManager.getAllShares()
        XCTAssertEqual(remainingShares.count, 1)
        XCTAssertEqual(remainingShares.first?.filePath, "/test/path/valid.txt")
    }

    // MARK: - ShareItem Tests

    func testShareItemInitialization() {
        let shareId = UUID()
        let shareItem = ShareItem(
            shareId: shareId,
            filePath: "/test/path/file.txt",
            shareType: .file,
            permission: .readWrite,
            expiresAt: nil
        )

        XCTAssertEqual(shareItem.shareId, shareId)
        XCTAssertEqual(shareItem.filePath, "/test/path/file.txt")
        XCTAssertEqual(shareItem.shareType, .file)
        XCTAssertEqual(shareItem.permission, .readWrite)
        XCTAssertNil(shareItem.expiresAt)
        XCTAssertFalse(shareItem.isExpired)
        XCTAssertTrue(shareItem.isValid)
        XCTAssertFalse(shareItem.accessToken.isEmpty)
    }

    func testShareItemExpiration() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        let shareItem = ShareItem(
            filePath: "/test/path/file.txt",
            shareType: .file,
            permission: .readOnly,
            expiresAt: futureDate
        )

        XCTAssertFalse(shareItem.isExpired)
        XCTAssertTrue(shareItem.isValid)
    }

    func testShareItemIsExpired() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let shareItem = ShareItem(
            filePath: "/test/path/file.txt",
            shareType: .file,
            permission: .readOnly,
            expiresAt: pastDate
        )

        XCTAssertTrue(shareItem.isExpired)
        XCTAssertFalse(shareItem.isValid)
    }

    func testShareTypeLocalizedDescription() {
        XCTAssertEqual(ShareType.file.localizedDescription, "文件")
        XCTAssertEqual(ShareType.folder.localizedDescription, "文件夹")
        XCTAssertEqual(ShareType.album.localizedDescription, "相册")
    }

    func testPermissionLocalizedDescription() {
        XCTAssertEqual(Permission.readOnly.localizedDescription, "只读")
        XCTAssertEqual(Permission.readWrite.localizedDescription, "读写")
    }
}
