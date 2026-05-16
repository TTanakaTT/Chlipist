import Cocoa
import CryptoKit
import Security

/// Monitors NSPasteboard and maintains a history of copied text items.
final class ClipboardManager {

  // MARK: - Singleton

  static let shared = ClipboardManager()
  private init() {
    loadHistory()
  }

  // MARK: - Public State

  /// Ordered clipboard history — newest entry at index 0.
  private(set) var history: [String] = []

  /// Maximum number of history entries to keep.
  let maxHistoryCount = 50

  // MARK: - Private State

  private var timer: Timer?
  private var lastChangeCount: Int = 0

  /// How often to poll NSPasteboard for changes (seconds).
  private let pollingInterval: TimeInterval = 0.5
  private let persistenceDirectoryName = "chlipist"
  private let persistenceFileName = "data"
  private let keychainService = "chlipist.clipboard-history"
  private let keychainAccount = "default"

  // MARK: - Monitoring

  func startMonitoring() {
    lastChangeCount = NSPasteboard.general.changeCount
    // Poll every 0.5 s — lightweight and compatible without entitlements.
    timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) {
      [weak self] _ in
      self?.poll()
    }
    RunLoop.main.add(timer!, forMode: .common)
  }

  func stopMonitoring() {
    timer?.invalidate()
    timer = nil
  }

  // MARK: - History Management

  func clearHistory() {
    let previousHistory = history
    history.removeAll()

    do {
      try persistHistory()
    } catch {
      history = previousHistory
      NSLog("ClipboardManager: failed to clear persisted history (%@)", error.localizedDescription)
    }
  }

  /// Directly sets the pasteboard to `item` (used just before pasting back).
  func setClipboard(_ item: String) {
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(item, forType: .string)
  }

  // MARK: - Private

  private func poll() {
    let pb = NSPasteboard.general
    let currentCount = pb.changeCount
    guard currentCount != lastChangeCount else { return }
    lastChangeCount = currentCount

    guard let text = pb.string(forType: .string), !text.isEmpty else { return }

    let updatedHistory = ClipboardHistory.updatedHistory(
      afterRecording: text,
      in: history,
      maxCount: maxHistoryCount
    )

    guard updatedHistory != history else { return }

    history = updatedHistory

    saveHistory()
  }

  private func loadHistory() {
    guard let fileURL = historyFileURL() else { return }

    do {
      let data = try Data(contentsOf: fileURL)
      let persistenceKey = try loadOrCreatePersistenceKey()
      history = try ClipboardHistoryPersistence.history(
        from: data,
        maxCount: maxHistoryCount,
        using: persistenceKey
      )
    } catch let error as NSError
      where isCocoaError(error, code: CocoaError.fileReadNoSuchFile.rawValue)
    {
      return
    } catch {
      NSLog("ClipboardManager: failed to load persisted history (%@)", error.localizedDescription)
    }
  }

  private func saveHistory() {
    do {
      try persistHistory()
    } catch {
      NSLog("ClipboardManager: failed to persist history (%@)", error.localizedDescription)
    }
  }

  private func persistHistory() throws {
    guard let fileURL = historyFileURL() else { return }

    if history.isEmpty {
      try removePersistedHistoryIfNeeded(at: fileURL)
      return
    }

    try ensurePersistenceDirectoryExists(for: fileURL)
    let persistenceKey = try loadOrCreatePersistenceKey()
    let data = try ClipboardHistoryPersistence.encryptedData(
      for: history,
      maxCount: maxHistoryCount,
      using: persistenceKey
    )
    try writeDataSecurely(data, to: fileURL)
  }

  private func historyFileURL() -> URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
      .appendingPathComponent(persistenceDirectoryName, isDirectory: true)
      .appendingPathComponent(persistenceFileName, isDirectory: false)
  }

  private func ensurePersistenceDirectoryExists(for fileURL: URL) throws {
    let fileManager = FileManager.default
    let directoryURL = fileURL.deletingLastPathComponent()
    var isDirectory: ObjCBool = false

    if fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
      guard isDirectory.boolValue else {
        throw NSError(
          domain: NSCocoaErrorDomain,
          code: NSFileWriteInvalidFileNameError,
          userInfo: [NSFilePathErrorKey: directoryURL.path]
        )
      }

      try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
      try excludeFromBackup(directoryURL)
      return
    }

    do {
      try fileManager.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
      )
    } catch let error as NSError
      where isCocoaError(error, code: NSFileWriteFileExistsError)
    {
      var createdIsDirectory: ObjCBool = false
      guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &createdIsDirectory),
        createdIsDirectory.boolValue
      else {
        throw error
      }

      try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
    }

    try excludeFromBackup(directoryURL)
  }

  private func removePersistedHistoryIfNeeded(at fileURL: URL) throws {
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }
  }

  private func writeDataSecurely(_ data: Data, to fileURL: URL) throws {
    let fileManager = FileManager.default
    let directoryURL = fileURL.deletingLastPathComponent()
    let tempURL = directoryURL.appendingPathComponent(
      ".\(persistenceFileName).\(UUID().uuidString).tmp")
    var shouldRemoveTempFile = true

    defer {
      if shouldRemoveTempFile, fileManager.fileExists(atPath: tempURL.path) {
        try? fileManager.removeItem(at: tempURL)
      }
    }

    let created = fileManager.createFile(
      atPath: tempURL.path,
      contents: nil,
      attributes: [.posixPermissions: 0o600]
    )
    guard created else {
      throw NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileWriteUnknownError,
        userInfo: [NSFilePathErrorKey: tempURL.path]
      )
    }

    try data.write(to: tempURL)

    if fileManager.fileExists(atPath: fileURL.path) {
      _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
    } else {
      try fileManager.moveItem(at: tempURL, to: fileURL)
    }

    try excludeFromBackup(fileURL)

    shouldRemoveTempFile = false
  }

  private func loadOrCreatePersistenceKey() throws -> SymmetricKey {
    if let persistedKeyData = try loadPersistedKeyData() {
      return SymmetricKey(data: persistedKeyData)
    }

    let key = SymmetricKey(size: .bits256)
    try savePersistedKeyData(key.dataRepresentation)
    return key
  }

  private func loadPersistedKeyData() throws -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: kCFBooleanTrue as Any,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    switch status {
    case errSecSuccess:
      guard let data = item as? Data else {
        throw ClipboardManagerKeychainError.unexpectedKeyData
      }
      return data
    case errSecItemNotFound:
      return nil
    default:
      throw ClipboardManagerKeychainError.osStatus(status)
    }
  }

  private func savePersistedKeyData(_ data: Data) throws {
    let addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
      kSecValueData as String: data,
    ]

    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

    switch addStatus {
    case errSecSuccess:
      return
    case errSecDuplicateItem:
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: keychainAccount,
        kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
      ]
      let attributesToUpdate: [String: Any] = [
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecValueData as String: data,
      ]
      let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
      guard updateStatus == errSecSuccess else {
        throw ClipboardManagerKeychainError.osStatus(updateStatus)
      }
    default:
      throw ClipboardManagerKeychainError.osStatus(addStatus)
    }
  }

  private func excludeFromBackup(_ url: URL) throws {
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var mutableURL = url
    try mutableURL.setResourceValues(values)
  }

  private func isCocoaError(_ error: NSError, code: Int) -> Bool {
    error.domain == NSCocoaErrorDomain && error.code == code
  }
}

private enum ClipboardManagerKeychainError: Error {
  case unexpectedKeyData
  case osStatus(OSStatus)
}

extension SymmetricKey {
  var dataRepresentation: Data {
    withUnsafeBytes { Data($0) }
  }
}
