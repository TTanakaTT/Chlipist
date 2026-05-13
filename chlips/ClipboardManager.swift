import Cocoa

/// Monitors NSPasteboard and maintains a history of copied text items.
final class ClipboardManager {

    // MARK: - Singleton

    static let shared = ClipboardManager()
    private init() {}

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
        history.removeAll()
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
    }
}
