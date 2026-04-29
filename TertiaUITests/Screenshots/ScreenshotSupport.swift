//
//  ScreenshotSupport.swift
//  TertiaUITests
//
//  Capture helpers for screenshot tests.
//

import XCTest

enum ScreenshotPaths {
    static let baseDirectory = "/tmp/tertia-screenshots"
}

extension XCTestCase {
    /// Captures the current screen and writes it to disk at
    /// `/tmp/tertia-screenshots/<name>.png`. Also attaches it to the test
    /// result bundle for inline review in Xcode.
    @MainActor
    func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let fm = FileManager.default
        let dir = URL(fileURLWithPath: ScreenshotPaths.baseDirectory, isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("\(name).png")
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("Failed to write screenshot \(name): \(error)")
        }
    }
}
