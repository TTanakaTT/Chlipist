import Cocoa
import Combine

final class AppCoordinator: HotKeyServiceDelegate, PasteboardMonitorDelegate,
  StatusBarControllerDelegate, HistoryMenuControllerDelegate
{
  private let clipboardService: ClipboardServiceProtocol
  private let monitor: PasteboardMonitorProtocol
  private let hotKeyService: HotKeyServiceProtocol
  private let robot: RobotProtocol

  private let statusBarController: StatusBarController
  private let historyMenuController: HistoryMenuController

  private var cancellables = Set<AnyCancellable>()

  init(
    clipboardService: ClipboardServiceProtocol,
    monitor: PasteboardMonitorProtocol,
    hotKeyService: HotKeyServiceProtocol,
    robot: RobotProtocol,
    statusBarController: StatusBarController,
    historyMenuController: HistoryMenuController
  ) {
    self.clipboardService = clipboardService
    self.monitor = monitor
    self.hotKeyService = hotKeyService
    self.robot = robot
    self.statusBarController = statusBarController
    self.historyMenuController = historyMenuController

    self.monitor.delegate = self
    self.hotKeyService.delegate = self
    self.statusBarController.delegate = self
    self.historyMenuController.delegate = self
  }

  func start() {
    monitor.start()
    hotKeyService.register()
  }

  // MARK: - HotKeyServiceDelegate

  func hotKeyDidPress() {
    showHistory()
  }

  // MARK: - PasteboardMonitorDelegate

  func pasteboardDidChange(_ pasteboard: NSPasteboard) {
    if let text = pasteboard.string(forType: .string), !text.isEmpty {
      clipboardService.add(text)
    }
  }

  // MARK: - StatusBarControllerDelegate

  func statusBarControllerDidSelectShowHistory() {
    showHistory()
  }

  func statusBarControllerDidSelectClearHistory() {
    clipboardService.clearHistory()
  }

  func statusBarControllerDidSelectQuit() {
    NSApp.terminate(nil)
  }

  // MARK: - HistoryMenuControllerDelegate

  func historyMenuControllerDidSelectItem(_ item: String) {
    clipboardService.setClipboard(item)
    // Delay slightly to allow application switch if it was just triggered
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      self.robot.simulatePaste()
    }
  }

  // MARK: - Private

  private func showHistory() {
    historyMenuController.show(with: clipboardService.history)
  }
}
