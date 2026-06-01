////
////  M3U8DownloaderTests.swift
////  DownloadManagerTests
////
////  Created by ace wei on 2026/6/1.
////
//
//import XCTest
//@testable import DownloadManager
//
//final class M3U8DownloaderTests: XCTestCase {
//
//    var downloader: M3U8Downloader!
//    var tempDirectory: URL!
//
//    override func setUp() {
//        super.setUp()
//
//        let tempDir = FileManager.default.temporaryDirectory
//        tempDirectory = tempDir.appendingPathComponent("M3U8DownloaderTests_\(UUID().uuidString)", isDirectory: true)
//        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
//
//        downloader = M3U8Downloader()
//        downloader.segmentConcurrency = 2
//        downloader.maxRetryCount = 3
//    }
//
//    override func tearDown() {
//        downloader = nil
//        try? FileManager.default.removeItem(at: tempDirectory)
//        super.tearDown()
//    }
//
//    // MARK: - Task Status Tests
//
//    func testInitialTaskStatus() {
//        let task = createTask()
//
//        XCTAssertEqual(task.status, .pending)
//        XCTAssertEqual(task.progress, 0)
//        XCTAssertEqual(task.downloadedSegments, 0)
//    }
//
//    func testPauseUpdatesStatus() {
//        let task = createTask()
//        task.updateStatus(.downloadingSegments)
//
//        downloader.pause(task: task)
//
//        XCTAssertEqual(task.status, .paused)
//    }
//
//    func testCancelUpdatesStatus() {
//        let task = createTask()
//        task.updateStatus(.downloadingSegments)
//
//        downloader.cancel(task: task)
//
//        XCTAssertEqual(task.status, .cancelled)
//    }
//
//    // MARK: - Concurrency Control Tests
//
//    func testSegmentConcurrencyConfiguration() {
//        XCTAssertEqual(downloader.segmentConcurrency, 2)
//
//        downloader.segmentConcurrency = 4
//        XCTAssertEqual(downloader.segmentConcurrency, 4)
//
//        downloader.segmentConcurrency = 1
//        XCTAssertEqual(downloader.segmentConcurrency, 1)
//    }
//
//    func testMaxRetryCountConfiguration() {
//        XCTAssertEqual(downloader.maxRetryCount, 3)
//
//        downloader.maxRetryCount = 5
//        XCTAssertEqual(downloader.maxRetryCount, 5)
//    }
//
//    // MARK: - Progress Tracking Tests
//
//    func testUpdateProgress() {
//        let task = createTask()
//
//        task.updateProgress(downloaded: 5, total: 10)
//
//        XCTAssertEqual(task.downloadedSegments, 5)
//        XCTAssertEqual(task.totalSegments, 10)
//        XCTAssertEqual(task.progress, 0.5)
//    }
//
//    func testUpdateProgressWithZeroTotal() {
//        let task = createTask()
//
//        task.updateProgress(downloaded: 0, total: 0)
//
//        XCTAssertEqual(task.progress, 0)
//    }
//
//    // MARK: - Current Segment Tracking Tests
//
//    func testUpdateCurrentSegment() {
//        let task = createTask()
//        let segmentURL = URL(string: "https://example.com/segment0.ts")!
//
//        task.updateCurrentSegment(index: 0, url: segmentURL)
//
//        XCTAssertEqual(task.currentSegmentIndex, 0)
//        XCTAssertEqual(task.currentSegmentURL, segmentURL)
//    }
//
//    func testClearCurrentSegment() {
//        let task = createTask()
//        let segmentURL = URL(string: "https://example.com/segment0.ts")!
//
//        task.updateCurrentSegment(index: 0, url: segmentURL)
//        task.updateCurrentSegment(index: nil, url: nil)
//
//        XCTAssertNil(task.currentSegmentIndex)
//        XCTAssertNil(task.currentSegmentURL)
//    }
//
//    // MARK: - Segment Downloaded Tracking Tests
//
//    func testMarkSegmentDownloaded() {
//        let task = createTask()
//
//        XCTAssertFalse(task.isSegmentDownloaded(0))
//        XCTAssertFalse(task.isSegmentDownloaded(1))
//
//        task.markSegmentDownloaded(0)
//
//        XCTAssertTrue(task.isSegmentDownloaded(0))
//        XCTAssertFalse(task.isSegmentDownloaded(1))
//    }
//
//    func testMultipleSegmentsDownloaded() {
//        let task = createTask()
//
//        task.markSegmentDownloaded(0)
//        task.markSegmentDownloaded(2)
//        task.markSegmentDownloaded(5)
//
//        XCTAssertTrue(task.isSegmentDownloaded(0))
//        XCTAssertFalse(task.isSegmentDownloaded(1))
//        XCTAssertTrue(task.isSegmentDownloaded(2))
//        XCTAssertFalse(task.isSegmentDownloaded(3))
//        XCTAssertFalse(task.isSegmentDownloaded(4))
//        XCTAssertTrue(task.isSegmentDownloaded(5))
//    }
//
//    func testDuplicateSegmentMarking() {
//        let task = createTask()
//
//        task.markSegmentDownloaded(0)
//        task.markSegmentDownloaded(0)
//
//        XCTAssertTrue(task.isSegmentDownloaded(0))
//    }
//
//    // MARK: - Resume Data Tests
//
//    func testResumeWithExistingPlaylist() async {
//        let task = createTask()
//
//        let playlist = M3U8Playlist(
//            url: URL(string: "https://example.com/test.m3u8")!,
//            type: .media,
//            variants: [],
//            segments: createMockSegments(count: 3),
//            totalDuration: 30
//        )
//
//        task.playlist = playlist
//        task.markSegmentDownloaded(0)
//        task.markSegmentDownloaded(1)
//        task.updateProgress(downloaded: 2, total: 3)
//
//        XCTAssertEqual(task.downloadedSegments, 2)
//        XCTAssertEqual(task.progress, 2.0 / 3.0)
//    }
//
//    // MARK: - Speed Limit Tests
//
//    func testSpeedLimitConfiguration() {
//        XCTAssertEqual(downloader.speedLimit, 0)
//
//        downloader.speedLimit = 1024 * 1024
//        XCTAssertEqual(downloader.speedLimit, 1024 * 1024)
//
//        downloader.speedLimit = 0
//        XCTAssertEqual(downloader.speedLimit, 0)
//    }
//
//    func testUpdateSpeed() {
//        let task = createTask()
//
//        task.updateSpeed(1024 * 100)
//
//        XCTAssertEqual(task.speed, 1024 * 100)
//    }
//
//    // MARK: - Error Handling Tests
//
//    func testFailTask() {
//        let task = createTask()
//        let error = M3U8DownloaderError.invalidPlaylist
//
//        task.fail(with: error)
//
//        XCTAssertEqual(task.status, .failed)
//        XCTAssertNotNil(task.error)
//    }
//
//    func testErrorDescription() {
//        let errors: [(M3U8DownloaderError, String)] = [
//            (.invalidPlaylist, "无效的播放列表"),
//            (.noSegments, "没有分片需要下载"),
//            (.cancelled, "已取消"),
//            (.downloadFailed(NSError(domain: "", code: -1)), "下载失败"),
//            (.mergeFailed(NSError(domain: "", code: -1)), "合并失败")
//        ]
//
//        for (error, expected) in errors {
//            XCTAssertTrue(error.localizedDescription.contains(expected.components(separatedBy: ":").first ?? expected))
//        }
//    }
//
//    // MARK: - Task Lifecycle Tests
//
//    func testCompleteTask() {
//        let task = createTask()
//        let outputURL = tempDirectory.appendingPathComponent("output.mp4")
//
//        try? Data().write(to: outputURL)
//
//        task.complete(with: outputURL)
//
//        XCTAssertEqual(task.status, .completed)
//        XCTAssertEqual(task.progress, 1.0)
//    }
//
//    func testCancelFlag() {
//        let task = createTask()
//
//        XCTAssertFalse(task.isCancelledFlag)
//
//        task.cancel()
//
//        XCTAssertTrue(task.isCancelledFlag)
//        XCTAssertEqual(task.status, .cancelled)
//    }
//
//    // MARK: - Playlist Handling Tests
//
//    func testMasterPlaylistVariantSelection() async {
//        let task = createTask()
//
//        let masterPlaylist = M3U8Playlist(
//            url: URL(string: "https://example.com/master.m3u8")!,
//            type: .master,
//            variants: [
//                VariantStream(bandwidth: 1280000, resolution: "720x480", codecs: nil, url: URL(string: "https://example.com/low.m3u8")!),
//                VariantStream(bandwidth: 2560000, resolution: "1280x720", codecs: nil, url: URL(string: "https://example.com/high.m3u8")!)
//            ],
//            segments: []
//        )
//
//        task.playlist = masterPlaylist
//
//        XCTAssertEqual(task.playlist?.type, .master)
//        XCTAssertEqual(task.playlist?.variants.count, 2)
//    }
//
//    // MARK: - Helper Methods
//
//    private func createTask() -> M3U8DownloadTask {
//        return M3U8DownloadTask(
//            url: URL(string: "https://example.com/test.m3u8")!,
//            savePath: tempDirectory
//        )
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
//}
