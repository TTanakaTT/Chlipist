import Cocoa
import ApplicationServices
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?
    private var launchAtLoginItem: NSMenuItem?

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the app from the Dock (LSUIElement handles this at launch,
        // but we also set it programmatically for safety).
        NSApp.setActivationPolicy(.accessory)

        enableLaunchAtLoginByDefault()

        setupStatusBarItem()
        checkAccessibilityPermission()
        ClipboardManager.shared.startMonitoring()

        hotKeyManager = HotKeyManager()
        hotKeyManager?.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardManager.shared.stopMonitoring()
    }

    // MARK: - Status Bar

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        if let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: localized("app.name")) {
            image.size = NSSize(width: 18, height: 18)
            button.image = image
        } else {
            button.title = "📋"
        }

        button.toolTip = localized("status.tooltip")

        let launchItem = NSMenuItem(title: localized("menu.launchAtLogin"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        launchAtLoginItem = launchItem

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: localized("menu.showHistory"), action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: localized("menu.clearHistory"), action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(launchItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: localized("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func showHistory() {
        ClipboardHistoryWindowController.shared.showPanel()
    }

    @objc private func clearHistory() {
        ClipboardManager.shared.clearHistory()
    }

    // MARK: - Launch at Login

    private func enableLaunchAtLoginByDefault() {
        let service = SMAppService.mainApp
        guard service.status != .enabled else { return }

        do {
            try service.register()
        } catch {
            NSLog("AppDelegate: failed to enable launch at login by default (%@)", error.localizedDescription)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                launchAtLoginItem?.state = .off
            } else {
                try service.register()
                launchAtLoginItem?.state = .on
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = localized("alert.launchAtLoginFailed.title")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: - Accessibility

    private func checkAccessibilityPermission() {
        guard !AXIsProcessTrusted() else { return }

        // Prompt the system dialog asking the user to grant access.
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        let alert = NSAlert()
        alert.messageText = localized("alert.accessibility.title")
        alert.informativeText = localized("alert.accessibility.message")
        alert.addButton(withTitle: localized("alert.accessibility.openSettings"))
        alert.addButton(withTitle: localized("alert.accessibility.later"))
        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
}
