import Cocoa

protocol StatusBarControllerDelegate: AnyObject {
  func statusBarControllerDidSelectShowHistory()
  func statusBarControllerDidSelectClearHistory()
  func statusBarControllerDidSelectQuit()
}

final class StatusBarController: NSObject {
  weak var delegate: StatusBarControllerDelegate?

  private var statusItem: NSStatusItem?

  override init() {
    super.init()
    setupStatusBarItem()
  }

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

    let menu = NSMenu()

    let showHistoryItem = NSMenuItem(
      title: NSLocalizedString("menu.showHistory", comment: "Show History"),
      action: #selector(showHistory),
      keyEquivalent: "v"
    )
    showHistoryItem.target = self
    showHistoryItem.keyEquivalentModifierMask = [.command, .shift]
    menu.addItem(showHistoryItem)

    menu.addItem(NSMenuItem.separator())

    let clearHistoryItem = NSMenuItem(
      title: NSLocalizedString("menu.clearHistory", comment: "Clear History"),
      action: #selector(clearHistory),
      keyEquivalent: ""
    )
    clearHistoryItem.target = self
    menu.addItem(clearHistoryItem)

    menu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(
      title: NSLocalizedString("menu.quit", comment: "Quit"),
      action: #selector(quit),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem?.menu = menu
  }

  @objc private func showHistory() {
    delegate?.statusBarControllerDidSelectShowHistory()
  }

  @objc private func clearHistory() {
    delegate?.statusBarControllerDidSelectClearHistory()
  }

  @objc private func quit() {
    delegate?.statusBarControllerDidSelectQuit()
  }
}
