import Cocoa

final class ClipboardHistoryWindowController: NSObject {

    static let shared = ClipboardHistoryWindowController()

    private let topLevelItemLimit = 10
    private let shortcutKeyEquivalents = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private let pasteSimulationDelay: TimeInterval = 0.15

    private var previousApp: NSRunningApplication?
    private var lastExternalApp: NSRunningApplication?
    private var anchorWindow: NSWindow?

    private override init() {
        super.init()
        lastExternalApp = frontmostExternalApplication()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivateApplication(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func showPanel() {
        previousApp = frontmostExternalApplication() ?? lastExternalApp
        let menu = buildMenu(from: ClipboardManager.shared.history)
        present(menu)
    }

    @objc private func workspaceDidActivateApplication(_ notification: Notification) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return
        }

        lastExternalApp = app
    }

    private func frontmostExternalApplication() -> NSRunningApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return app.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : app
    }

    private func buildMenu(from history: [String]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        guard !history.isEmpty else {
            let item = NSMenuItem(title: NSLocalizedString("history.empty", comment: ""), action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return menu
        }

        for (index, item) in history.prefix(topLevelItemLimit).enumerated() {
            menu.addItem(historyItem(for: item, keyEquivalent: shortcutKeyEquivalents[index]))
        }

        if history.count > topLevelItemLimit {
            menu.addItem(.separator())

            let moreItem = NSMenuItem(title: NSLocalizedString("history.more", comment: ""), action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: moreItem.title)
            submenu.autoenablesItems = false

            for item in history.dropFirst(topLevelItemLimit) {
                submenu.addItem(historyItem(for: item, keyEquivalent: ""))
            }

            moreItem.submenu = submenu
            menu.addItem(moreItem)
        }

        return menu
    }

    private func historyItem(for item: String, keyEquivalent: String) -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: item.menuDisplayTitle,
            action: #selector(selectHistoryItem(_:)),
            keyEquivalent: keyEquivalent
        )
        menuItem.target = self
        menuItem.keyEquivalentModifierMask = []
        menuItem.representedObject = item
        menuItem.toolTip = item
        return menuItem
    }

    private func present(_ menu: NSMenu) {
        let mouseLocation = NSEvent.mouseLocation
        let frame = NSRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)
        let anchorWindow = MenuAnchorWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        anchorWindow.backgroundColor = .clear
        anchorWindow.hasShadow = false
        anchorWindow.ignoresMouseEvents = true
        anchorWindow.isOpaque = false
        anchorWindow.level = .statusBar
        anchorWindow.collectionBehavior = [.transient, .ignoresCycle]

        let anchorView = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        anchorWindow.contentView = anchorView

        self.anchorWindow = anchorWindow
        anchorWindow.orderFrontRegardless()
        menu.popUp(positioning: nil, at: .zero, in: anchorView)
        anchorWindow.orderOut(nil)
        self.anchorWindow = nil
    }

    @objc private func selectHistoryItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? String else { return }
        pasteItem(item)
    }

    private func pasteItem(_ item: String) {
        ClipboardManager.shared.setClipboard(item)

        guard let app = previousApp else { return }
        app.activate(options: .activateIgnoringOtherApps)

        DispatchQueue.main.asyncAfter(deadline: .now() + pasteSimulationDelay) {
            self.simulateCmdV()
        }
    }

    private func simulateCmdV() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let vKey: CGKeyCode = 9

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}

private final class MenuAnchorWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private extension String {
    var menuDisplayTitle: String {
        let singleLine = self
            .replacingOccurrences(of: "\r\n", with: " ↵ ")
            .replacingOccurrences(of: "\n", with: " ↵ ")
            .replacingOccurrences(of: "\r", with: " ↵ ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let normalized = singleLine.isEmpty ? self : singleLine
        let maxLength = 80

        guard normalized.count > maxLength else { return normalized }
        return String(normalized.prefix(maxLength - 1)) + "…"
    }
}
