import Carbon
import Cocoa

// MARK: - C-compatible hotkey callback (file-scope free function)

/// Top-level free function used as the Carbon event handler.
/// Being a named free function (not a closure) guarantees it is treated as
/// a plain C function pointer by the compiler — no captures needed.
private func chlipistHotKeyHandler(
  _ callRef: EventHandlerCallRef?,
  _ event: EventRef?,
  _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
  DispatchQueue.main.async {
    ClipboardHistoryWindowController.shared.showPanel()
  }
  return noErr
}

// MARK: - HotKeyManager

/// Registers a global ⌘⇧V hotkey using the Carbon Event Manager.
/// Unlike NSEvent.addGlobalMonitorForEvents, Carbon hotkeys do NOT require
/// Accessibility permission — they work out of the box.
final class HotKeyManager {

  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?

  /// Four-char signature for this app: 'chlp' = 0x63_68_6C_70.
  private let chlipistSignature: OSType = 0x6368_6C70

  func register() {
    var hotKeyID = EventHotKeyID()
    hotKeyID.signature = chlipistSignature
    hotKeyID.id = 1

    // ⌘ + ⇧ + V
    let modifiers = UInt32(cmdKey | shiftKey)
    let keyCode = UInt32(kVK_ANSI_V)

    let status = RegisterEventHotKey(
      keyCode,
      modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )

    guard status == noErr else {
      NSLog("HotKeyManager: RegisterEventHotKey failed (%d)", status)
      return
    }

    var eventSpec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )

    InstallEventHandler(
      GetApplicationEventTarget(),
      chlipistHotKeyHandler,  // plain C function pointer — no captures
      1,
      &eventSpec,
      nil,
      &eventHandlerRef
    )
  }

  deinit {
    if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
    if let ref = eventHandlerRef { RemoveEventHandler(ref) }
  }
}
