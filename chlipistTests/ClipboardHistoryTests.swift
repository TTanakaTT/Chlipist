import XCTest
@testable import chlipist

final class ClipboardHistoryTests: XCTestCase {
    func testUpdatedHistoryAddsNewestItemToFront() {
        let history = ClipboardHistory.updatedHistory(
            afterRecording: "third",
            in: ["second", "first"],
            maxCount: 50
        )

        XCTAssertEqual(history, ["third", "second", "first"])
    }

    func testUpdatedHistoryMovesExistingItemToFrontWithoutDuplicates() {
        let history = ClipboardHistory.updatedHistory(
            afterRecording: "second",
            in: ["third", "second", "first"],
            maxCount: 50
        )

        XCTAssertEqual(history, ["second", "third", "first"])
    }

    func testUpdatedHistoryIgnoresItemAlreadyAtFront() {
        let history = ClipboardHistory.updatedHistory(
            afterRecording: "third",
            in: ["third", "second", "first"],
            maxCount: 50
        )

        XCTAssertEqual(history, ["third", "second", "first"])
    }

    func testUpdatedHistoryTrimsToMaximumCount() {
        let history = ClipboardHistory.updatedHistory(
            afterRecording: "fourth",
            in: ["third", "second", "first"],
            maxCount: 3
        )

        XCTAssertEqual(history, ["fourth", "third", "second"])
    }

    func testSanitizedPersistedHistoryDropsEmptyItemsWithinMaxCountWindow() {
        let history = ClipboardHistory.sanitizedPersistedHistory(
            ["third", "", "second", "first"],
            maxCount: 3
        )

        XCTAssertEqual(history, ["third", "second"])
    }
}