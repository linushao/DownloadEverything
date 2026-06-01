////
////  M3U8IntegrationTests.swift
////  DownloadManagerTests
////
////  Created by ace wei on 2026/6/1.
////
//
//import XCTest
//@testable import DownloadManager
//
//final class M3U8IntegrationTests: XCTestCase {
//
//    var downloader: M3U8Downloader!
//    var tempDirectory: URL!
//    var outputDirectory: URL!
//
//    override func setUp() {
//        super.setUp()
//
//        let tempDir = FileManager.default.temporaryDirectory
//        tempDirectory = tempDir.appendingPathComponent("M3U8IntegrationTests_\(UUID().uuidString)", isDirectory: true)
//        outputDirectory = tempDir.appendingPathComponent("M3U8IntegrationOutput_\(UUID().uuidString)", isDirectory: true)
//
//        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
//        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
//
//        downloader = M3U8Downloader()
//        downloader.segmentConcurrency = 2
//        downloader.maxRetryCount = 3
//    }
//
//    override func tearDown() {
//        downloader = nil
//        try? FileManager.default.removeItem(at: tempDirectory)
//        try? FileManager.default.removeItem(at: outputDirectory)
//        super.tearDown()
//    }
//
//    // MARK: - Complete Download Flow Tests
//
//    func testCompleteDownloadFlowSimulation() async throws {
//        let task = createTask()
//
//        XCTAssertEqual(task.status, .pending)
//        XCTAssertEqual(task.progress, 0)
//
//        task.updateStatus(.parsing)
//        XCTAssertEqual(task.status, .parsing)
//
//        let playlist = createMediaPlaylist(segmentCount: 5)
//        task.playlist = playlist
//        task.updateProgress(downloaded: 0, total: 5)
//
//        XCTAssertEqual(task.status, .parsing)
//
//        task.updateStatus(.downloadingSegments)
//
//        for i in 0..<5 {
//            try await simulateSegmentDownload(task: task, segmentIndex: i)
//            task.updateProgress(downloaded: i + 1, total: 5)
//        }
//
//        XCTAssertEqual(task.downloadedSegments, 5)
//        XCTAssertEqual(task.progress, 1.0)
//
//        task.updateStatus(.merging)
//        XCTAssertEqual(task.status, .merging)
//
//        let outputURL = outputDirectory.appendingPathComponent("output.mp4")
//        try Data().write(to: outputURL)
//
//        task.complete(with: outputURL)
//
//        XCTAssertEqual(task.status, .completed)
//        XCTAssertEqual(task.progress, 1.0)
//    }
//
//    func testPauseResumeFlow() async throws {
//        let task = createTask()
//        let playlist = createMediaPlaylist(segmentCount: 5)
//        task.playlist = playlist
//
//        task.updateStatus(.downloadingSegments)
//        task.updateProgress(downloaded: 2, total: 5)
//
//        downloader.pause(task: task)
//        XCTAssertEqual(task.status, .paused)
//        XCTAssertEqual(task.downloadedSegments, 2)
//
//        let pausedProgress = task.progress
//
//        task.updateStatus(.downloadingSegments)
//
//        for i in 2..<5 {
//            try await simulateSegmentDownload(task: task, segmentIndex: i)
//            task.updateProgress(downloaded: i + 1, total: 5)
//        }
//
//        XCTAssertGreaterThan(task.progress, pausedProgress)
//        XCTAssertEqual(task.downloadedSegments, 5)
//    }
//
//    func testCancelAndCleanupFlow() async throws {
//        let task = createTask()
//        let playlist = createMediaPlaylist(segmentCount: 5)
//        task.playlist = playlist
//
//        task.updateStatus(.downloadingSegments)
//        task.updateProgress(downloaded: 2, total: 5)
//
//        try task.createTempDirectory()
//        let segmentPath = task.tempSegmentPath(for: 0)
//        try Data(repeating: 0, count: 100).write(to: segmentPath)
//
//        XCTAssertTrue(FileManager.default.fileExists(atPath: task.tempDirectory.path))
//        XCTAssertTrue(FileManager.default.fileExists(atPath: segmentPath.path))
//
//        downloader.cancel(task: task)
//
//        XCTAssertEqual(task.status, .cancelled)
//        XCTAssertTrue(task.isCancelledFlag)
//    }
//
//    // MARK: - Concurrent Task Tests
//
//    func testMultipleConcurrentM3U8Tasks() async throws {
//        let tasks = (0..<3).map { index -> M3U8DownloadTask in
//            let task = M3U8DownloadTask(
//                url: URL(string: "https://example.com/test\(index).m3u8")!,
//                savePath: tempDirectory.appendingPathComponent("task\(index)")
//            )
//            try? FileManager.default.createDirectory(at: task.savePath, withIntermediateDirectories: true)
//            return task
//        }
//
//        XCTAssertEqual(tasks.count, 3)
//
//        for (index, task) in tasks.enumerated() {
//            let playlist = createMediaPlaylist(segmentCount: 2)
//            task.playlist = playlist
//            task.updateStatus(.downloadingSegments)
//            task.updateProgress(downloaded: 0, total: 2)
//
//            for segIndex in 0..<2 {
//                try await simulateSegmentDownload(task: task, segmentIndex: segIndex)
//                task.updateProgress(downloaded: segIndex + 1, total: 2)
//            }
//
//            let outputURL = task.savePath.appendingPathComponent("output\(index).mp4")
//            try Data().write(to: outputURL)
//            task.complete(with: outputURL)
//        }
//
//        for task in tasks {
//            XCTAssertEqual(task.status, .completed)
//            XCTAssertEqual(task.progress, 1.0)
//        }
//    }
//
//    // MARK: - Breakpoint Resume Tests
//
//    func testResumeWithPartialDownload() async throws {
//        let task = createTask()
//        let playlist = createMediaPlaylist(segmentCount: 5)
//        task.playlist = playlist
//
//        try task.createTempDirectory()
//
//        for i in 0..<3 {
//            let segmentPath = task.tempSegmentPath(for: i)
//            try Data(repeating: 0, count: 100 * (i + 1)).write(to: segmentPath)
//            task.markSegmentDownloaded(i)
//        }
//
//        task.updateProgress(downloaded: 3, total: 5)
//
//        XCTAssertTrue(task.isSegmentDownloaded(0))
//        XCTAssertTrue(task.isSegmentDownloaded(1))
//        XCTAssertTrue(task.isSegmentDownloaded(2))
//        XCTAssertFalse(task.isSegmentDownloaded(3))
//        XCTAssertFalse(task.isSegmentDownloaded(4))
//
//        for i in 3..<5 {
//            try await simulateSegmentDownload(task: task, segmentIndex: i)
//            task.updateProgress(downloaded: i + 1, total: 5)
//        }
//
//        XCTAssertEqual(task.downloadedSegments, 5)
//        XCTAssertEqual(task.progress, 1.0)
//    }
//
//    func testSimulatedRestartResume() async throws {
//        let taskId = UUID()
//        let originalTempDir = tempDirectory.appendingPathComponent(taskId.uuidString, isDirectory: true)
//        try FileManager.default.createDirectory(at: originalTempDir, withIntermediateDirectories: true)
//
//        for i in 0..<3 {
//            let segmentPath = originalTempDir.appendingPathComponent("segment_\(i).ts")
//            try Data(repeating: 0, count: 100).write(to: segmentPath)
//        }
//
//        let newTask = M3U8DownloadTask(
//            taskId: taskId,
//            url: URL(string: "https://example.com/test.m3u8")!,
//            savePath: tempDirectory
//        )
//        newTask.tempDirectory = originalTempDir
//
//        let playlist = createMediaPlaylist(segmentCount: 5)
//        newTask.playlist = playlist
//
//        newTask.markSegmentDownloaded(0)
//        newTask.markSegmentDownloaded(1)
//        newTask.markSegmentDownloaded(2)
//        newTask.updateProgress(downloaded: 3, total: 5)
//
//        XCTAssertTrue(newTask.isSegmentDownloaded(0))
//        XCTAssertTrue(newTask.isSegmentDownloaded(1))
//        XCTAssertTrue(newTask.isSegmentDownloaded(2))
//
//        for i in 3..<5 {
//            let segmentPath = newTask.tempSegmentPath(for: i)
//            try Data(repeating: 0, count: 100).write(to: segmentPath)
//            newTask.markSegmentDownloaded(i)
//            newTask.updateProgress(downloaded: i + 1, total: 5)
//        }
//
//        XCTAssertEqual(newTask.downloadedSegments, 5)
//        XCTAssertEqual(newTask.progress, 1.0)
//    }
//
//    // MARK: - Edge Case Tests
//
//    func testEmptyPlaylistHandling() async {
//        let task = createTask()
//
//        do {
//            let emptyPlaylist = M3U8Playlist(
//                url: URL(string: "https://example.com/empty.m3u8")!,
//                type: .media,
//                variants: [],
//                segments: [],
//                totalDuration: 0
//            )
//            task.playlist = emptyPlaylist
//            task.updateStatus(.downloadingSegments)
//
//            if emptyPlaylist.segments.isEmpty {
//                task.fail(with: M3U8DownloaderError.noSegments)
//            }
//
//            XCTAssertEqual(task.status, .failed)
//            XCTAssertNotNil(task.error)
//        }
//    }
//
//    func testZeroSegmentDuration() async throws {
//        let segments = [
//            MediaSegment(
//                sequenceNumber: 0,
//                url: URL(string: "https://example.com/seg0.ts")!,
//                duration: 0,
//                encryptionMethod: .none
//            ),
//            MediaSegment(
//                sequenceNumber: 1,
//                url: URL(string: "https://example.com/seg1.ts")!,
//                duration: 0,
//                encryptionMethod: .none
//            )
//        ]
//
//        let playlist = M3U8Playlist(
//            url: URL(string: "https://example.com/test.m3u8")!,
//            type: .media,
//            variants: [],
//            segments: segments,
//            totalDuration: 0
//        )
//
//        XCTAssertEqual(playlist.segments.count, 2)
//        XCTAssertEqual(playlist.totalDuration, 0)
//    }
//
//    func testVeryLargeSegmentCount() async throws {
//        let largeCount = 150
//        let segments = (0..<largeCount).map { index -> MediaSegment in
//            MediaSegment(
//                sequenceNumber: index,
//                url: URL(string: "https://example.com/segment\(index).ts")!,
//                duration: 10.0,
//                encryptionMethod: .none
//            )
//        }
//
//        let playlist = M3U8Playlist(
//            url: URL(string: "https://example.com/large.m3u8")!,
//            type: .media,
//            variants: [],
//            segments: segments,
//            totalDuration: TimeInterval(largeCount) * 10.0
//        )
//
//        XCTAssertEqual(playlist.segments.count, largeCount)
//        XCTAssertEqual(playlist.totalDuration, TimeInterval(largeCount * 10))
//    }
//
//    func testTaskEqualityByTaskId() {
//        let taskId = UUID()
//        let url = URL(string: "https://example.com/test.m3u8")!
//
//        let task1 = M3U8DownloadTask(taskId: taskId, url: url, savePath: tempDirectory)
//        let task2 = M3U8DownloadTask(taskId: taskId, url: url, savePath: tempDirectory)
//
//        XCTAssertEqual(task1.taskId, task2.taskId)
//        XCTAssertNotEqual(task1.id, task2.id)
//    }
//
//    func testMultipleEncryptionKeyChanges() async throws {
//        let segments = [
//            MediaSegment(
//                sequenceNumber: 0,
//                url: URL(string: "https://example.com/seg0.ts")!,
//                duration: 10.0,
//                encryptionMethod: .none
//            ),
//            MediaSegment(
//                sequenceNumber: 1,
//                url: URL(string: "https://example.com/seg1.ts")!,
//                duration: 10.0,
//                encryptionMethod: .aes128,
//                encryptionKeyURI: URL(string: "https://example.com/key1.bin"),
//                initializationVector: "0x1111"
//            ),
//            MediaSegment(
//                sequenceNumber: 2,
//                url: URL(string: "https://example.com/seg2.ts")!,
//                duration: 10.0,
//                encryptionMethod: .aes128,
//                encryptionKeyURI: URL(string: "https://example.com/key2.bin"),
//                initializationVector: "0x2222"
//            ),
//            MediaSegment(
//                sequenceNumber: 3,
//                url: URL(string: "https://example.com/seg3.ts")!,
//                duration: 10.0,
//                encryptionMethod: .none
//            )
//        ]
//
//        XCTAssertEqual(segments[0].encryptionMethod, .none)
//        XCTAssertEqual(segments[1].encryptionMethod, .aes128)
//        XCTAssertEqual(segments[2].encryptionMethod, .aes128)
//        XCTAssertNotEqual(segments[1].encryptionKeyURI, segments[2].encryptionKeyURI)
//        XCTAssertEqual(segments[3].encryptionMethod, .none)
//    }
//
//    // MARK: - Helper Methods
//
//    private func createTask() -> M3U8DownloadTask {
//        return M3U8DownloadTask(
//            url: URL(string: "https://example.com/test.m3u8")!,
//            savePath: outputDirectory
//        )
//    }
//
//    private func createMediaPlaylist(segmentCount: Int) -> M3U8Playlist {
//        let segments = (0..<segmentCount).map { index -> MediaSegment in
//            MediaSegment(
//                sequenceNumber: index,
//                url: URL(string: "https://example.com/segment\(index).ts")!,
//                duration: 10.0,
//                encryptionMethod: .none
//            )
//        }
//
//        return M3U8Playlist(
//            url: URL(string: "https://example.com/test.m3u8")!,
//            type: .media,
//            variants: [],
//            segments: segments,
//            totalDuration: TimeInterval(segmentCount) * 10.0
//        )
//    }
//
//    private func simulateSegmentDownload(task: M3U8DownloadTask, segmentIndex: Int) async throws {
//        try await Task.sleep(nanoseconds: 10_000_000)
//
//        let segmentPath = task.tempSegmentPath(for: segmentIndex)
//        try Data(repeating: 0, count: 100).write(to: segmentPath)
//        task.markSegmentDownloaded(segmentIndex)
//    }
//}
//
//// MARK: - Apple Official HLS Test Streams Reference
//
//extension M3U8IntegrationTests {
//
//    struct HLS_TestStream {
//        let name: String
//        let url: URL
//        let description: String
//    }
//
//    func testAppleOfficialHLSStreamsReference() {
//        let streams: [HLS_TestStream] = [
//            HLS_TestStream(
//                name: "Big Buck Bunny",
//                url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")!,
//                description: "Apple official HLS test stream - Advanced Example"
//            ),
//            HLS_TestStream(
//                name: "Basic Advanced",
//                url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_fmp4/master.m3u8")!,
//                description: "Apple HLS test stream with multiple bitrates"
//            )
//        ]
//
//        XCTAssertFalse(streams.isEmpty)
//
//        for stream in streams {
//            XCTAssertTrue(stream.url.absoluteString.hasPrefix("https://devstreaming-cdn.apple.com"))
//            XCTAssertTrue(stream.url.absoluteString.hasSuffix(".m3u8"))
//        }
//    }
//
//    func testVariantStreamSelectionLogic() async throws {
//        let variants = [
//            VariantStream(bandwidth: 1280000, resolution: "720x480", codecs: nil, url: URL(string: "https://example.com/low.m3u8")!),
//            VariantStream(bandwidth: 2560000, resolution: "1280x720", codecs: nil, url: URL(string: "https://example.com/mid.m3u8")!),
//            VariantStream(bandwidth: 5000000, resolution: "1920x1080", codecs: nil, url: URL(string: "https://example.com/high.m3u8")!)
//        ]
//
//        let sortedByBandwidth = variants.sorted { $0.bandwidth < $1.bandwidth }
//
//        XCTAssertEqual(sortedByBandwidth.first?.bandwidth, 1280000)
//        XCTAssertEqual(sortedByBandwidth.last?.bandwidth, 5000000)
//
//        let firstVariant = sortedByBandwidth.first
//        XCTAssertNotNil(firstVariant)
//        XCTAssertEqual(firstVariant?.bandwidth, 1280000)
//    }
//}
