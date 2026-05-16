import CryptoKit
import XCTest

@testable import Chlipist

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

  func testEncryptedPersistenceRoundTripsHistory() throws {
    let key = SymmetricKey(data: Data(repeating: 0xAB, count: 32))
    let payload = try ClipboardHistoryPersistence.encryptedData(
      for: ["third", "second", "first"],
      maxCount: 50,
      using: key
    )

    let history = try ClipboardHistoryPersistence.history(
      from: payload,
      maxCount: 50,
      using: key
    )

    XCTAssertEqual(history, ["third", "second", "first"])
  }

  func testEncryptedPersistenceRejectsMalformedPayload() {
    let key = SymmetricKey(data: Data(repeating: 0xCD, count: 32))

    XCTAssertThrowsError(
      try ClipboardHistoryPersistence.history(
        from: Data("CHLP1".utf8),
        maxCount: 50,
        using: key
      )
    )
  }
}
