import Carbon
import Cocoa

/// A utility to simulate user interactions.
protocol RobotProtocol {
  func simulatePaste()
}

final class Robot: RobotProtocol {
  private let pasteSimulationDelay: TimeInterval = 0.15

  func simulatePaste() {
    guard let source = CGEventSource(stateID: .hidSystemState) else { return }
    let vKey: CGKeyCode = 9  // kVK_ANSI_V

    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
    keyDown?.flags = .maskCommand
    keyDown?.post(tap: .cghidEventTap)

    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
    keyUp?.flags = .maskCommand
    keyUp?.post(tap: .cghidEventTap)
  }
}
