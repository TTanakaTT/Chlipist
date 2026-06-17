import Cocoa

protocol PasteboardMonitorDelegate: AnyObject {
  func pasteboardDidChange(_ pasteboard: NSPasteboard)
}

protocol PasteboardMonitorProtocol: AnyObject {
  var delegate: PasteboardMonitorDelegate? { get set }
  func start()
  func stop()
}

final class PasteboardMonitor: PasteboardMonitorProtocol {
  weak var delegate: PasteboardMonitorDelegate?

  private var timer: Timer?
  private var lastChangeCount: Int = 0
  private let pollingInterval: TimeInterval = 0.5
  private let pasteboard = NSPasteboard.general

  func start() {
    lastChangeCount = pasteboard.changeCount
    timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) {
      [weak self] _ in
      self?.poll()
    }
    RunLoop.main.add(timer!, forMode: .common)
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  private func poll() {
    let currentCount = pasteboard.changeCount
    guard currentCount != lastChangeCount else { return }
    lastChangeCount = currentCount

    delegate?.pasteboardDidChange(pasteboard)
  }
}
