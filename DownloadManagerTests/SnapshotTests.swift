//
//  SnapshotTests.swift
//  DownloadManagerTests
//
//  Created by ace wei on 2026/5/28.
//

import SwiftUI
import UIKit
import XCTest

@testable import DownloadManager

final class SnapshotTests: XCTestCase {

    // MARK: - Properties

    private var recordMode: Bool {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "true"
    }

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Snapshot Tests

    func testDownloadRowViewSnapshot_Downloading() {
        let testURL = URL(string: "https://example.com/testfile.zip")!
        let savePath = FileUtils.shared.temporaryDirectory

        let task = DownloadTask(url: testURL, savePath: savePath, fileName: "testfile.zip")
        task.updateDownloadedBytes(50, totalBytes: 100)

        let view = DownloadRowView(
            task: task,
            onPause: {},
            onResume: {},
            onCancel: {},
            onRemove: {}
        )
        .frame(width: 320, height: 80)
        .preferredColorScheme(.light)

        assertSnapshot(
            matching: view,
            named: "download_row_view_downloading",
            record: recordMode
        )
    }

    func testDownloadRowViewSnapshot_Completed() {
        let testURL = URL(string: "https://example.com/completed.zip")!
        let savePath = FileUtils.shared.temporaryDirectory

        let task = DownloadTask(url: testURL, savePath: savePath, fileName: "completed.zip")
        task.status = .completed
        task.updateDownloadedBytes(100, totalBytes: 100)

        let view = DownloadRowView(
            task: task,
            onPause: {},
            onResume: {},
            onCancel: {},
            onRemove: {},
            onShare: {}
        )
        .frame(width: 320, height: 80)
        .preferredColorScheme(.light)

        assertSnapshot(
            matching: view,
            named: "download_row_view_completed",
            record: recordMode
        )
    }

    func testDownloadRowViewSnapshot_Paused() {
        let testURL = URL(string: "https://example.com/paused.zip")!
        let savePath = FileUtils.shared.temporaryDirectory

        let task = DownloadTask(url: testURL, savePath: savePath, fileName: "paused.zip")
        task.status = .paused
        task.updateDownloadedBytes(30, totalBytes: 100)

        let view = DownloadRowView(
            task: task,
            onPause: {},
            onResume: {},
            onCancel: {},
            onRemove: {}
        )
        .frame(width: 320, height: 80)
        .preferredColorScheme(.light)

        assertSnapshot(
            matching: view,
            named: "download_row_view_paused",
            record: recordMode
        )
    }

    func testDownloadRowViewSnapshot_Failed() {
        let testURL = URL(string: "https://example.com/failed.zip")!
        let savePath = FileUtils.shared.temporaryDirectory

        let task = DownloadTask(url: testURL, savePath: savePath, fileName: "failed.zip")
        task.status = .failed
        task.updateDownloadedBytes(50, totalBytes: 100)

        let view = DownloadRowView(
            task: task,
            onPause: {},
            onResume: {},
            onCancel: {},
            onRemove: {}
        )
        .frame(width: 320, height: 80)
        .preferredColorScheme(.light)

        assertSnapshot(
            matching: view,
            named: "download_row_view_failed",
            record: recordMode
        )
    }

    func testDownloadRowViewSnapshot_Waiting() {
        let testURL = URL(string: "https://example.com/waiting.zip")!
        let savePath = FileUtils.shared.temporaryDirectory

        let task = DownloadTask(url: testURL, savePath: savePath, fileName: "waiting.zip")
        task.status = .waiting

        let view = DownloadRowView(
            task: task,
            onPause: {},
            onResume: {},
            onCancel: {},
            onRemove: {}
        )
        .frame(width: 320, height: 80)
        .preferredColorScheme(.light)

        assertSnapshot(
            matching: view,
            named: "download_row_view_waiting",
            record: recordMode
        )
    }
}

// MARK: - Snapshot Assertion Helper

extension SnapshotTests {
    func assertSnapshot(
        matching view: some View,
        named name: String,
        record: Bool = false,
        perceptualPrecision: Float = 0.98
    ) {
        let snapshotDirectory = getSnapshotDirectory()
        let fileURL = snapshotDirectory.appendingPathComponent("\(name).png")

        let image = renderViewToImage(view)

        if record {
            try? FileManager.default.createDirectory(
                at: snapshotDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try? image.pngData()?.write(to: fileURL)
            return
        }

        guard FileManager.default.fileExists(atPath: fileURL.path),
            let referenceData = try? Data(contentsOf: fileURL),
            let referenceImage = UIImage(data: referenceData)
        else {
            try? FileManager.default.createDirectory(
                at: snapshotDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try? image.pngData()?.write(to: fileURL)
            return
        }

        let similarity = compareImages(image, referenceImage)
        XCTAssertGreaterThanOrEqual(
            similarity,
            perceptualPrecision,
            "Snapshot mismatch for \(name). Similarity: \(similarity * 100)% (required: \(perceptualPrecision * 100)%)"
        )
    }

    private func getSnapshotDirectory() -> URL {
        let testBundle = Bundle(for: type(of: self))
        return testBundle.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots", isDirectory: true)
    }

    private func renderViewToImage(_ view: some View) -> UIImage {
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.bounds = CGRect(x: 0, y: 0, width: 320, height: 80)
        hostingController.view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: hostingController.view.bounds.size)
        let image = renderer.image { _ in
            hostingController.view.drawHierarchy(
                in: hostingController.view.bounds,
                afterScreenUpdates: true
            )
        }
        return image
    }

    private func compareImages(_ image1: UIImage, _ image2: UIImage) -> Float {
        guard let cgImage1 = image1.cgImage, let cgImage2 = image2.cgImage else {
            return 0
        }

        let width = min(cgImage1.width, cgImage2.width)
        let height = min(cgImage1.height, cgImage2.height)

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        var pixels1 = [UInt8](repeating: 0, count: height * bytesPerRow)
        var pixels2 = [UInt8](repeating: 0, count: height * bytesPerRow)

        let context1 = CGContext(
            data: &pixels1,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        let context2 = CGContext(
            data: &pixels2,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context1?.draw(cgImage1, in: CGRect(x: 0, y: 0, width: width, height: height))
        context2?.draw(cgImage2, in: CGRect(x: 0, y: 0, width: width, height: height))

        var matchingPixels = 0
        let totalPixels = width * height

        for pixelIndex in 0..<(height * bytesPerRow) {
            if abs(Int(pixels1[pixelIndex]) - Int(pixels2[pixelIndex])) <= 10 {
                matchingPixels += 1
            }
        }

        return Float(matchingPixels) / Float(totalPixels)
    }
}
