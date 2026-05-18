import ApplicationServices
import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?
  private var hotKeyManager: HotKeyManager?
  private var launchAtLoginItem: NSMenuItem?
  private var showHistoryMenuItem: NSMenuItem?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Hide the app from the Dock (LSUIElement handles this at launch,
    // but we also set it programmatically for safety).
    NSApp.setActivationPolicy(.accessory)

    enableLaunchAtLoginByDefault()
    // Start workspace app tracking before the status item can open the history menu.
    _ = ClipboardHistoryWindowController.shared

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleClipboardHistoryDidChange),
      name: .clipboardHistoryDidChange,
      object: ClipboardManager.shared
    )

    setupStatusBarItem()
    checkAccessibilityPermission()
    ClipboardManager.shared.startMonitoring()

    hotKeyManager = HotKeyManager()
    hotKeyManager?.register()

    openStatusMenuOnLaunch()
  }

  func applicationWillTerminate(_ notification: Notification) {
    NotificationCenter.default.removeObserver(self)
    ClipboardManager.shared.stopMonitoring()
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showStatusMenu(after: 0)
    return false
  }

  // MARK: - Status Bar

  private func setupStatusBarItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    guard let button = statusItem?.button else { return }

    if let image = NSImage(
      systemSymbolName: "doc.on.clipboard",
      accessibilityDescription: NSLocalizedString("app.name", comment: ""))
    {
      image.size = NSSize(width: 18, height: 18)
      button.image = image
    } else {
      button.title = "📋"
    }

    let launchItem = NSMenuItem(
      title: NSLocalizedString("menu.launchAtLogin", comment: ""),
      action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    launchAtLoginItem = launchItem

    let menu = NSMenu()
    let pasteItem = NSMenuItem(
      title: "",
      action: #selector(showHistory),
      keyEquivalent: "v")
    pasteItem.keyEquivalentModifierMask = [.command, .shift]
    showHistoryMenuItem = pasteItem
    updateShowHistoryMenuItemTitle()
    menu.addItem(pasteItem)
    menu.addItem(
      NSMenuItem(
        title: NSLocalizedString("menu.clearHistory", comment: ""), action: #selector(clearHistory),
        keyEquivalent: ""))
    menu.addItem(.separator())
    menu.addItem(launchItem)
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: NSLocalizedString("menu.quit", comment: ""),
        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    statusMenu = menu
    statusItem?.menu = menu
  }

  @objc private func showHistory() {
    ClipboardHistoryWindowController.shared.showPanel()
  }

  @objc private func clearHistory() {
    ClipboardManager.shared.clearHistory()
  }

  @objc private func handleClipboardHistoryDidChange(_ notification: Notification) {
    updateShowHistoryMenuItemTitle()
  }

  private func updateShowHistoryMenuItemTitle() {
    let key = ClipboardManager.shared.history.isEmpty ? "menu.copyPrompt" : "menu.showHistory"
    showHistoryMenuItem?.title = NSLocalizedString(key, comment: "")
  }

  private func openStatusMenuOnLaunch() {
    showStatusMenu(after: 0.1)
  }

  private func showStatusMenu(after delay: TimeInterval) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      guard let self, let statusItem = self.statusItem, let statusMenu = self.statusMenu else {
        return
      }

      statusItem.popUpMenu(statusMenu)
    }
  }

  // MARK: - Launch at Login

  private func enableLaunchAtLoginByDefault() {
    let service = SMAppService.mainApp
    guard service.status != .enabled else { return }

    do {
      try service.register()
    } catch {
      NSLog(
        "AppDelegate: failed to enable launch at login by default (%@)", error.localizedDescription)
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
      alert.messageText = NSLocalizedString("alert.launchAtLoginFailed.title", comment: "")
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
  }
}
