import CryptoKit
import Foundation

struct ClipboardHistory {
  static func updatedHistory(afterRecording text: String, in history: [String], maxCount: Int)
    -> [String]
  {
    guard !text.isEmpty else { return history }
    guard text != history.first else { return history }

    var updatedHistory = history.filter { $0 != text }
    updatedHistory.insert(text, at: 0)

    if updatedHistory.count > maxCount {
      updatedHistory.removeLast(updatedHistory.count - maxCount)
    }

    return updatedHistory
  }

  static func sanitizedPersistedHistory(_ history: [String], maxCount: Int) -> [String] {
    Array(history.prefix(maxCount)).filter { !$0.isEmpty }
  }
}

enum ClipboardHistoryPersistenceError: Error {
  case malformedEncryptedPayload
}

struct ClipboardHistoryPersistence {
  enum LoadResult {
    case current([String])
    case migratedLegacy([String])

    var history: [String] {
      switch self {
      case .current(let history), .migratedLegacy(let history):
        return history
      }
    }

    var needsMigration: Bool {
      switch self {
      case .current:
        return false
      case .migratedLegacy:
        return true
      }
    }
  }

  private static let formatMagic = Data("CHLP1".utf8)

  static func encryptedData(
    for history: [String],
    maxCount: Int,
    using key: SymmetricKey
  ) throws -> Data {
    let sanitizedHistory = ClipboardHistory.sanitizedPersistedHistory(history, maxCount: maxCount)
    let encodedHistory = try JSONEncoder().encode(sanitizedHistory)
    let sealedBox = try AES.GCM.seal(encodedHistory, using: key)

    guard let combined = sealedBox.combined else {
      throw ClipboardHistoryPersistenceError.malformedEncryptedPayload
    }

    var payload = Data()
    payload.reserveCapacity(formatMagic.count + combined.count)
    payload.append(formatMagic)
    payload.append(combined)
    return payload
  }

  static func loadResult(
    from data: Data,
    maxCount: Int,
    using key: SymmetricKey
  ) throws -> LoadResult {
    if data.starts(with: formatMagic) {
      let encryptedPayload = data.dropFirst(formatMagic.count)
      guard !encryptedPayload.isEmpty else {
        throw ClipboardHistoryPersistenceError.malformedEncryptedPayload
      }

      let sealedBox = try AES.GCM.SealedBox(combined: Data(encryptedPayload))
      let decryptedData = try AES.GCM.open(sealedBox, using: key)
      let decodedHistory = try JSONDecoder().decode([String].self, from: decryptedData)
      return .current(
        ClipboardHistory.sanitizedPersistedHistory(decodedHistory, maxCount: maxCount)
      )
    }

    let decodedHistory = try JSONDecoder().decode([String].self, from: data)
    return .migratedLegacy(
      ClipboardHistory.sanitizedPersistedHistory(decodedHistory, maxCount: maxCount)
    )
  }
}
