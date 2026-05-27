//
//  DownloadManagerTests.swift
//  DownloadManagerTests
//
//  Created by ace wei on 2026/5/27.
//

import XCTest
@testable import DownloadManager

final class DownloadManagerTests: XCTestCase {

    var downloadManager: DownloadManager!

    override func setUp() {
        super.setUp()
        downloadManager = DownloadManager.shared
        downloadManager.maxConcurrentTasks = 4
        downloadManager.maxRetryCount = 3
        downloadManager.speedLimit = 0
        downloadManager.retryDelay = 0.1
    }

    override func tearDown() {
        // 清理所有任务
        downloadManager.cancelAll()

        // 等待异步操作完成
        let expectation = XCTestExpectation(description: "Cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.downloadManager.clearCompletedTasks()
            self.downloadManager.clearFailedTasks()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        downloadManager = nil
        super.tearDown()
    }

    // MARK: - Task Management Tests

    func testAddTask() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let taskId = downloadManager.addTask(url: testURL)

        XCTAssertNotNil(taskId)
        XCTAssertEqual(downloadManager.tasks.count, 1)

        let task = downloadManager.getTask(taskId: taskId)
        XCTAssertNotNil(task)
        XCTAssertEqual(task?.url, testURL)
        XCTAssertEqual(task?.status, .waiting)
    }

    func testAddMultipleTasks() {
        let url1 = URL(string: "https://example.com/file1.zip")!
        let url2 = URL(string: "https://example.com/file2.zip")!
        let url3 = URL(string: "https://example.com/file3.zip")!

        let id1 = downloadManager.addTask(url: url1)
        let id2 = downloadManager.addTask(url: url2)
        let id3 = downloadManager.addTask(url: url3)

        XCTAssertEqual(downloadManager.tasks.count, 3)
        XCTAssertNotEqual(id1, id2)
        XCTAssertNotEqual(id2, id3)
    }

    func testRemoveTask() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let taskId = downloadManager.addTask(url: testURL)

        XCTAssertEqual(downloadManager.tasks.count, 1)

        let result = downloadManager.removeTask(taskId: taskId)
        XCTAssertTrue(result)
        XCTAssertEqual(downloadManager.tasks.count, 0)
    }

    func testRemoveNonExistentTask() {
        let result = downloadManager.removeTask(taskId: UUID())
        XCTAssertFalse(result)
    }

    // MARK: - Task Status Tests

    func testTaskStatusTransitions() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let taskId = downloadManager.addTask(url: testURL)

        guard let task = downloadManager.getTask(taskId: taskId) else {
            XCTFail("Task should exist")
            return
        }

        XCTAssertEqual(task.status, .waiting)

        task.status = .downloading
        XCTAssertEqual(task.status, .downloading)

        task.status = .paused
        XCTAssertEqual(task.status, .paused)

        task.status = .completed
        XCTAssertEqual(task.status, .completed)

        task.status = .failed
        XCTAssertEqual(task.status, .failed)
    }

    // MARK: - Download Control Tests

    func testPauseTask() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let taskId = downloadManager.addTask(url: testURL)

        let task = downloadManager.getTask(taskId: taskId)
        task?.status = .downloading

        let result = downloadManager.pauseTask(taskId: taskId)
        XCTAssertTrue(result)
    }

    func testResumeTask() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let taskId = downloadManager.addTask(url: testURL)

        let task = downloadManager.getTask(taskId: taskId)
        task?.status = .paused

        let result = downloadManager.resumeTask(taskId: taskId)
        XCTAssertTrue(result)
    }

    func testCancelTask() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let taskId = downloadManager.addTask(url: testURL)

        let result = downloadManager.cancelTask(taskId: taskId)
        XCTAssertTrue(result)
    }

    func testCancelAll() {
        let url1 = URL(string: "https://example.com/file1.zip")!
        let url2 = URL(string: "https://example.com/file2.zip")!

        downloadManager.addTask(url: url1)
        downloadManager.addTask(url: url2)

        downloadManager.cancelAll()
        XCTAssertTrue(downloadManager.tasks.allSatisfy { $0.status == .failed })
    }

    // MARK: - Speed Limit Tests

    func testSpeedLimitProperty() {
        XCTAssertEqual(downloadManager.speedLimit, 0)

        downloadManager.speedLimit = 1024 * 1024 // 1MB/s
        XCTAssertEqual(downloadManager.speedLimit, 1024 * 1024)

        downloadManager.speedLimit = 0 // 0 means no limit
        XCTAssertEqual(downloadManager.speedLimit, 0)
    }

    // MARK: - Retry Mechanism Tests

    func testMaxRetryCountProperty() {
        XCTAssertEqual(downloadManager.maxRetryCount, 3)

        downloadManager.maxRetryCount = 5
        XCTAssertEqual(downloadManager.maxRetryCount, 5)
    }

    func testRetryDelayProperty() {
        XCTAssertEqual(downloadManager.retryDelay, 0.1)

        downloadManager.retryDelay = 2.0
        XCTAssertEqual(downloadManager.retryDelay, 2.0)
    }

    func testRetryCountIncrement() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let taskId = downloadManager.addTask(url: testURL)

        guard let task = downloadManager.getTask(taskId: taskId) else {
            XCTFail("Task should exist")
            return
        }

        XCTAssertEqual(task.retryCount, 0)

        task.retryCount += 1
        XCTAssertEqual(task.retryCount, 1)

        task.retryCount += 1
        XCTAssertEqual(task.retryCount, 2)
    }

    // MARK: - Concurrency Tests

    func testMaxConcurrentTasksProperty() {
        XCTAssertEqual(downloadManager.maxConcurrentTasks, 4)

        downloadManager.maxConcurrentTasks = 2
        XCTAssertEqual(downloadManager.maxConcurrentTasks, 2)
    }

    func testConcurrentTaskLimit() {
        downloadManager.maxConcurrentTasks = 2

        let url1 = URL(string: "https://example.com/file1.zip")!
        let url2 = URL(string: "https://example.com/file2.zip")!
        let url3 = URL(string: "https://example.com/file3.zip")!

        downloadManager.addTask(url: url1)
        downloadManager.addTask(url: url2)
        downloadManager.addTask(url: url3)

        let downloadingTasks = downloadManager.tasks.filter { $0.status == .downloading }
        XCTAssertLessThanOrEqual(downloadingTasks.count, downloadManager.maxConcurrentTasks)
    }

    // MARK: - DownloadTask Tests

    func testDownloadTaskInitialization() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let savePath = FileUtils.shared.temporaryDirectory

        let task = DownloadTask(url: testURL, savePath: savePath, fileName: "custom.zip")

        XCTAssertEqual(task.url, testURL)
        XCTAssertEqual(task.fileName, "custom.zip")
        XCTAssertEqual(task.savePath, savePath)
        XCTAssertEqual(task.status, .waiting)
        XCTAssertEqual(task.retryCount, 0)
    }

    func testDownloadTaskProgress() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let savePath = FileUtils.shared.temporaryDirectory

        let task = DownloadTask(url: testURL, savePath: savePath)

        XCTAssertEqual(task.progress, 0)

        task.updateDownloadedBytes(50, totalBytes: 100)
        XCTAssertEqual(task.progress, 0.5, accuracy: 0.001)

        task.updateDownloadedBytes(100, totalBytes: 100)
        XCTAssertEqual(task.progress, 1.0)
    }

    func testDownloadTaskResetForRetry() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let savePath = FileUtils.shared.temporaryDirectory

        let task = DownloadTask(url: testURL, savePath: savePath)

        task.status = .failed
        task.retryCount = 1
        task.lastError = NSError(domain: "Test", code: -1)

        task.resetForRetry()

        XCTAssertEqual(task.status, .waiting)
        XCTAssertNil(task.lastError)
    }
}
