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
        // 取消所有任务
        downloadManager.cancelAll()

        // 等待取消操作完成
        let cancelExpectation = XCTestExpectation(description: "Cancel all")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            cancelExpectation.fulfill()
        }
        wait(for: [cancelExpectation], timeout: 1.0)

        // 同步等待所有任务被清理
        let semaphore = DispatchSemaphore(value: 0)
        var cleanupAttempts = 0
        let maxAttempts = 20

        func attemptCleanup() {
            let tasks = downloadManager.getAllTasks()
            if tasks.isEmpty {
                semaphore.signal()
                return
            }

            cleanupAttempts += 1
            if cleanupAttempts >= maxAttempts {
                // 强制清理 - 直接删除所有任务
                for task in tasks {
                    _ = downloadManager.removeTask(taskId: task.taskId)
                }
                semaphore.signal()
                return
            }

            // 继续等待
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                attemptCleanup()
            }
        }

        attemptCleanup()
        _ = semaphore.wait(timeout: .now() + 10.0)

        downloadManager = nil
        super.tearDown()
    }

    // MARK: - Task Management Tests

    func testAddTask() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let taskId = downloadManager.addTask(url: testURL)

        XCTAssertNotNil(taskId)
        // 使用 getAllTasks() 确保线程安全访问
        XCTAssertEqual(downloadManager.getAllTasks().count, 1)

        let task = downloadManager.getTask(taskId: taskId)
        XCTAssertNotNil(task)
        XCTAssertEqual(task?.url, testURL)
        // 任务可能处于 waiting 或 downloading 状态（取决于并发限制）
        XCTAssertTrue([DownloadStatus.waiting, .downloading].contains(task?.status ?? .failed))
    }

    func testAddMultipleTasks() {
        let url1 = URL(string: "https://example.com/file1.zip")!
        let url2 = URL(string: "https://example.com/file2.zip")!
        let url3 = URL(string: "https://example.com/file3.zip")!

        // 记录添加前的任务数量
        let initialCount = downloadManager.getAllTasks().count

        let id1 = downloadManager.addTask(url: url1)
        let id2 = downloadManager.addTask(url: url2)
        let id3 = downloadManager.addTask(url: url3)

        // 等待任务添加完成
        let expectation = XCTestExpectation(description: "Wait for tasks")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // 使用 getAllTasks() 确保线程安全访问
        let taskCount = downloadManager.getAllTasks().count
        XCTAssertEqual(
            taskCount, initialCount + 3, "Expected \(initialCount + 3) tasks but got \(taskCount)")
        XCTAssertNotEqual(id1, id2, "id1 and id2 should be different")
        XCTAssertNotEqual(id2, id3, "id2 and id3 should be different")
    }

    func testRemoveTask() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let taskId = downloadManager.addTask(url: testURL)

        // 使用 getAllTasks() 确保线程安全访问
        XCTAssertEqual(downloadManager.getAllTasks().count, 1)

        let result = downloadManager.removeTask(taskId: taskId)
        XCTAssertTrue(result)
        // 使用 getAllTasks() 确保线程安全访问
        XCTAssertEqual(downloadManager.getAllTasks().count, 0)
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

        // 任务可能处于 waiting 或 downloading 状态
        XCTAssertTrue([DownloadStatus.waiting, .downloading].contains(task.status))

        // 测试状态转换
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

        // 等待异步操作完成
        let expectation = XCTestExpectation(description: "Cancel all tasks")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // 使用 getAllTasks() 确保线程安全访问
        let allTasks = downloadManager.getAllTasks()
        // 取消后的任务状态应该是 failed 或 waiting
        XCTAssertTrue(allTasks.allSatisfy { $0.status == .failed || $0.status == .waiting })
    }

    // MARK: - Speed Limit Tests

    func testSpeedLimitProperty() {
        XCTAssertEqual(downloadManager.speedLimit, 0)

        downloadManager.speedLimit = 1024 * 1024  // 1MB/s
        XCTAssertEqual(downloadManager.speedLimit, 1024 * 1024)

        downloadManager.speedLimit = 0  // 0 means no limit
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
