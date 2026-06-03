import Cocoa

protocol HistoryMenuControllerDelegate: AnyObject {
  func historyMenuControllerDidSelectItem(_ item: String)
}

final class HistoryMenuController: NSObject, NSMenuDelegate {
  weak var delegate: HistoryMenuControllerDelegate?

  private static let shortcutKeyEquivalents = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
  private static let maxTopLevelItems = shortcutKeyEquivalents.count

  private var anchorWindow: NSWindow?
  private var previousApp: NSRunningApplication?
  private var lastExternalApp: NSRunningApplication?

  override init() {
    super.init()
    lastExternalApp = frontmostExternalApplication()
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(workspaceDidActivateApplication(_:)),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )
  }

  func show(with history: [String]) {
    previousApp = frontmostExternalApplication() ?? lastExternalApp
    let menu = buildMenu(from: history)
    present(menu)
  }

  private func buildMenu(from history: [String]) -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false
    menu.delegate = self

    guard !history.isEmpty else {
      let item = NSMenuItem(
        title: NSLocalizedString("history.empty", comment: ""), action: nil, keyEquivalent: "")
      item.isEnabled = false
      menu.addItem(item)
      return menu
    }

    for (index, item) in history.prefix(Self.maxTopLevelItems).enumerated() {
      menu.addItem(historyItem(for: item, keyEquivalent: Self.shortcutKeyEquivalents[index]))
    }

    if history.count > Self.maxTopLevelItems {
      menu.addItem(.separator())
      let moreItem = NSMenuItem(
        title: NSLocalizedString("history.more", comment: ""), action: nil, keyEquivalent: "")
      let submenu = NSMenu(title: moreItem.title)
      submenu.autoenablesItems = false
      for item in history.dropFirst(Self.maxTopLevelItems) {
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
    menuItem.toolTip = item.menuDisplayToolTip
    return menuItem
  }

  @objc private func selectHistoryItem(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? String else { return }

    // Activate previous app before notifying delegate to paste
    if let app = previousApp {
      app.activate(options: .activateIgnoringOtherApps)
    }

    delegate?.historyMenuControllerDidSelectItem(item)
  }

  private func present(_ menu: NSMenu) {
    let mouseLocation = NSEvent.mouseLocation
    let frame = NSRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)
    let anchorWindow = NSWindow(
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
    menu.popUp(positioning: menu.items.first { $0.isEnabled }, at: .zero, in: anchorView)
    anchorWindow.orderOut(nil)
    self.anchorWindow = nil
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
}
