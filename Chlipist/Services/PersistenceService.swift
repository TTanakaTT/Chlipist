import CryptoKit
import Foundation
import Security

protocol PersistenceServiceProtocol {
  func load() -> [String]
  func save(_ history: [String])
}

final class PersistenceService: PersistenceServiceProtocol {
  private let directoryName = "Chlipist"
  private let fileName = "data"
  private let maxHistoryCount = 50
  private let keychainService = "Chlipist.clipboard-history"
  private let keychainAccount = "default"

  func load() -> [String] {
    guard let fileURL = historyFileURL() else { return [] }
    do {
      let data = try Data(contentsOf: fileURL)
      let key = try loadOrCreatePersistenceKey()
      return try ClipboardHistoryPersistence.history(
        from: data,
        maxCount: maxHistoryCount,
        using: key
      )
    } catch {
      return []
    }
  }

  func save(_ history: [String]) {
    guard let fileURL = historyFileURL() else { return }
    do {
      if history.isEmpty {
        try removePersistedHistoryIfNeeded(at: fileURL)
        return
      }
      try ensurePersistenceDirectoryExists(for: fileURL)
      let key = try loadOrCreatePersistenceKey()
      let data = try ClipboardHistoryPersistence.encryptedData(
        for: history,
        maxCount: maxHistoryCount,
        using: key
      )
      try data.write(to: fileURL, options: .atomic)
    } catch {
      NSLog("PersistenceService: Failed to save history (%@)", error.localizedDescription)
    }
  }

  // MARK: - Private (Ported from ClipboardManager)

  private func historyFileURL() -> URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
      .appendingPathComponent(directoryName, isDirectory: true)
      .appendingPathComponent(fileName, isDirectory: false)
  }

  private func loadOrCreatePersistenceKey() throws -> SymmetricKey {
    if let keyData = try loadKeyFromKeychain() {
      return SymmetricKey(data: keyData)
    }
    let newKey = SymmetricKey(size: .bits256)
    let keyData = newKey.withUnsafeBytes { Data($0) }
    try saveKeyToKeychain(keyData)
    return newKey
  }

  private func loadKeyFromKeychain() throws -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecReturnData as String: true,
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecSuccess { return result as? Data }
    if status == errSecItemNotFound { return nil }
    throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
  }

  private func saveKeyToKeychain(_ data: Data) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let status = SecItemAdd(query as CFDictionary, nil)
    if status != errSecSuccess {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }

  private func ensurePersistenceDirectoryExists(for fileURL: URL) throws {
    let directoryURL = fileURL.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: directoryURL.path) {
      try FileManager.default.createDirectory(
        at: directoryURL, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
  }

  private func removePersistedHistoryIfNeeded(at fileURL: URL) throws {
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }
  }
}
