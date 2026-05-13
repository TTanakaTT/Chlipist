import Cocoa

// MARK: - ClipboardHistoryWindowController

/// Floating panel that shows clipboard history.
/// - Triggered by the global ⌘⇧V hotkey (or the status-bar menu).
/// - Type to search / filter entries.
/// - Arrow keys navigate the list; ↩ pastes the selected item; ⎋ closes.
final class ClipboardHistoryWindowController: NSWindowController {

    // MARK: - Singleton

    static let shared = ClipboardHistoryWindowController()

    // MARK: - UI Components

    private var searchField: NSSearchField!
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var countLabel: NSTextField!

    // MARK: - State

    private var filteredHistory: [String] = []
    /// The app that was frontmost before we showed this panel.
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?

    // MARK: - Init

    private init() {
        let panel = HistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Clipboard History — Chlips"
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 320, height: 260)

        super.init(window: panel)
        panel.delegate = self
        setupUI()
        setupKeyMonitor()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        // ── Search field ──────────────────────────────────────────────
        searchField = NSSearchField()
        searchField.placeholderString = "検索… (Search…)"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.target = self
        searchField.action = #selector(searchChanged)
        contentView.addSubview(searchField)

        // ── Count label ───────────────────────────────────────────────
        countLabel = NSTextField(labelWithString: "")
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        contentView.addSubview(countLabel)

        // ── Table view inside a scroll view ───────────────────────────
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .lineBorder

        tableView = NSTableView()
        tableView.style = .plain
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 28
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.headerView = nil
        tableView.target = self
        tableView.doubleAction = #selector(rowDoubleClicked)
        tableView.allowsEmptySelection = false
        tableView.selectionHighlightStyle = .regular

        let column = NSTableColumn(identifier: .init("ClipboardContent"))
        column.minWidth = 100
        tableView.addTableColumn(column)
        tableView.delegate = self
        tableView.dataSource = self

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        // ── Auto Layout ───────────────────────────────────────────────
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: countLabel.topAnchor, constant: -6),

            countLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            countLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            countLabel.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    // MARK: - Key Monitor

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.isKeyWindow == true else { return event }
            return self.handleKeyDown(event)
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        if let shortcutIndex = shortcutIndex(for: event) {
            guard shortcutIndex < filteredHistory.count else { return nil }
            tableView.selectRowIndexes(IndexSet(integer: shortcutIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(shortcutIndex)
            pasteItem(filteredHistory[shortcutIndex])
            return nil
        }

        switch event.keyCode {
        case 36, 76: // Return / numpad Enter
            pasteSelected()
            return nil
        case 53: // Escape
            closePanel()
            return nil
        case 125: // ↓
            let next = min(tableView.selectedRow + 1, filteredHistory.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
            tableView.scrollRowToVisible(next)
            return nil
        case 126: // ↑
            let prev = max(tableView.selectedRow - 1, 0)
            tableView.selectRowIndexes(IndexSet(integer: prev), byExtendingSelection: false)
            tableView.scrollRowToVisible(prev)
            return nil
        default:
            return event
        }
    }

    private func shortcutIndex(for event: NSEvent) -> Int? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.isEmpty else { return nil }

        switch event.keyCode {
        case 18, 83: return 0 // 1 / numpad 1
        case 19, 84: return 1 // 2 / numpad 2
        case 20, 85: return 2 // 3 / numpad 3
        case 21, 86: return 3 // 4 / numpad 4
        case 23, 87: return 4 // 5 / numpad 5
        case 22, 88: return 5 // 6 / numpad 6
        case 26, 89: return 6 // 7 / numpad 7
        case 28, 91: return 7 // 8 / numpad 8
        case 25, 92: return 8 // 9 / numpad 9
        case 29, 82: return 9 // 0 / numpad 0
        default: return nil
        }
    }

    // MARK: - Show / Hide

    func showPanel() {
        // Capture the current frontmost app *before* we steal focus.
        previousApp = NSWorkspace.shared.frontmostApplication

        // Reload data from the manager.
        filteredHistory = ClipboardManager.shared.history
        tableView.reloadData()
        updateCountLabel()

        // Select the first row.
        if !filteredHistory.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }

        // Position the panel near the mouse cursor.
        positionNearMouse()

        searchField.stringValue = ""
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(searchField)
    }

    func closePanel() {
        window?.orderOut(nil)
    }

    // MARK: - Positioning

    private func positionNearMouse() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let size = window.frame.size
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height)

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = max(visible.minX + 8, min(origin.x, visible.maxX - size.width - 8))
            origin.y = max(visible.minY + 8, min(origin.y, visible.maxY - size.height - 8))
        }
        window.setFrameOrigin(origin)
    }

    // MARK: - Constants

    /// Delay between activating the previous app and synthesising ⌘V.
    /// Gives macOS time to complete the app-activation transition (~100 ms
    /// measured in practice; 150 ms adds a small safety margin).
    private let pasteSimulationDelay: TimeInterval = 0.15

    // MARK: - Paste

    /// Pastes the currently selected row to the previous app.
    func pasteSelected() {
        guard tableView.selectedRow >= 0, tableView.selectedRow < filteredHistory.count else { return }
        pasteItem(filteredHistory[tableView.selectedRow])
    }

    private func pasteItem(_ item: String) {
        closePanel()

        // Put the chosen item on the pasteboard.
        ClipboardManager.shared.setClipboard(item)

        // Activate the previous app, then simulate ⌘V.
        guard let app = previousApp else { return }
        app.activate(options: .activateIgnoringOtherApps)

        DispatchQueue.main.asyncAfter(deadline: .now() + pasteSimulationDelay) {
            self.simulateCmdV()
        }
    }

    /// Synthesises a ⌘V key event so the previously active app pastes.
    /// Requires Accessibility permission (the user is prompted at launch).
    private func simulateCmdV() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let vKey: CGKeyCode = 9 // kVK_ANSI_V

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Search

    @objc private func searchChanged() {
        let query = searchField.stringValue
        if query.isEmpty {
            filteredHistory = ClipboardManager.shared.history
        } else {
            filteredHistory = ClipboardManager.shared.history.filter {
                $0.localizedCaseInsensitiveContains(query)
            }
        }
        tableView.reloadData()
        updateCountLabel()

        if !filteredHistory.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    private func updateCountLabel() {
        let total = ClipboardManager.shared.history.count
        let shown = filteredHistory.count
        if searchField.stringValue.isEmpty {
            countLabel.stringValue = "\(total) 件 / 最大 \(ClipboardManager.shared.maxHistoryCount) 件"
        } else {
            countLabel.stringValue = "\(shown) 件 / \(total) 件"
        }
    }

    // MARK: - Double-click

    @objc private func rowDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < filteredHistory.count else { return }
        pasteItem(filteredHistory[row])
    }
}

// MARK: - NSTableViewDataSource

extension ClipboardHistoryWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { filteredHistory.count }
}

// MARK: - NSTableViewDelegate

extension ClipboardHistoryWindowController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("HistoryCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView

        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier

            let tf = NSTextField()
            tf.isBezeled = false
            tf.drawsBackground = false
            tf.isEditable = false
            tf.isSelectable = false
            tf.lineBreakMode = .byTruncatingTail
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(tf)
            cell?.textField = tf

            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 8),
                tf.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
                tf.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
            ])
        }

        let raw = filteredHistory[row]
        // Collapse newlines for single-line display.
        let display = raw
            .replacingOccurrences(of: "\r\n", with: "↵")
            .replacingOccurrences(of: "\n", with: "↵")
            .replacingOccurrences(of: "\r", with: "↵")
        cell?.textField?.stringValue = display
        cell?.toolTip = raw.count > 200 ? String(raw.prefix(200)) + "…" : raw

        return cell
    }
}

// MARK: - NSWindowDelegate

extension ClipboardHistoryWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Reset search when the window is dismissed.
        searchField.stringValue = ""
        filteredHistory = []
        tableView.reloadData()
    }
}

// MARK: - HistoryPanel

/// NSPanel subclass that can always become key/main.
private class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
