import ApplicationServices
import Cocoa

struct AccessibilityPermission {
  static func check() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    AXIsProcessTrustedWithOptions(options as CFDictionary)
  }
}
