import Cocoa

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
    private let persistenceDirectoryName = "chlips"
    private let persistenceFileName = "clipboard-history.json"

    // MARK: - Monitoring

    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        // Poll every 0.5 s — lightweight and compatible without entitlements.
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
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

        // De-duplicate: don't add if already at the top of the list.
        if text == history.first { return }

        // Remove duplicate entry deeper in the list if it exists.
        history.removeAll { $0 == text }

        history.insert(text, at: 0)

        if history.count > maxHistoryCount {
            history.removeLast(history.count - maxHistoryCount)
        }

        saveHistory()
    }

    private func loadHistory() {
        guard let fileURL = historyFileURL() else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([String].self, from: data)
            history = Array(decoded.prefix(maxHistoryCount)).filter { !$0.isEmpty }
        } catch let error as NSError
            where isCocoaError(error, code: CocoaError.fileReadNoSuchFile.rawValue) {
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
        let data = try JSONEncoder().encode(Array(history.prefix(maxHistoryCount)))
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
            return
        }

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch let error as NSError
            where isCocoaError(error, code: NSFileWriteFileExistsError) {
            var createdIsDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &createdIsDirectory),
                  createdIsDirectory.boolValue else {
                throw error
            }

            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
        }
    }

    private func removePersistedHistoryIfNeeded(at fileURL: URL) throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func writeDataSecurely(_ data: Data, to fileURL: URL) throws {
        let fileManager = FileManager.default
        let directoryURL = fileURL.deletingLastPathComponent()
        let tempURL = directoryURL.appendingPathComponent(".\(persistenceFileName).\(UUID().uuidString).tmp")
        var shouldRemoveTempFile = true

        defer {
            guard shouldRemoveTempFile, fileManager.fileExists(atPath: tempURL.path) else { return }
            try? fileManager.removeItem(at: tempURL)
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

        shouldRemoveTempFile = false
    }

    private func isCocoaError(_ error: NSError, code: Int) -> Bool {
        error.domain == NSCocoaErrorDomain && error.code == code
    }
}
