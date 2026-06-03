import Carbon
import Cocoa

protocol HotKeyServiceDelegate: AnyObject {
  func hotKeyDidPress()
}

protocol HotKeyServiceProtocol: AnyObject {
  var delegate: HotKeyServiceDelegate? { get set }
  func register()
  func unregister()
}

// MARK: - C-compatible hotkey callback

private func hotKeyHandler(
  _ callRef: EventHandlerCallRef?,
  _ event: EventRef?,
  _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let userData = userData else { return noErr }
  let service = Unmanaged<HotKeyService>.fromOpaque(userData).takeUnretainedValue()

  DispatchQueue.main.async {
    service.delegate?.hotKeyDidPress()
  }
  return noErr
}

final class HotKeyService: HotKeyServiceProtocol {
  weak var delegate: HotKeyServiceDelegate?

  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private(set) var isRegistered = false
  private let hotKeySignature: OSType = 0x4348_4C50  // 'CHLP'

  func register() {
    guard !isRegistered else { return }

    var hotKeyID = EventHotKeyID()
    hotKeyID.signature = hotKeySignature
    hotKeyID.id = 1

    let modifiers = UInt32(cmdKey | shiftKey)
    let keyCode = UInt32(kVK_ANSI_V)

    let userData = Unmanaged.passUnretained(self).toOpaque()

    let status = RegisterEventHotKey(
      keyCode,
      modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )

    guard status == noErr else {
      return
    }

    var eventSpec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )

    let installStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      hotKeyHandler,
      1,
      &eventSpec,
      userData,
      &eventHandlerRef
    )

    if installStatus != noErr {
      if let ref = hotKeyRef {
        UnregisterEventHotKey(ref)
        hotKeyRef = nil
      }
      return
    }

    isRegistered = true
  }

  func unregister() {
    if let ref = hotKeyRef {
      UnregisterEventHotKey(ref)
      hotKeyRef = nil
    }

    if let ref = eventHandlerRef {
      RemoveEventHandler(ref)
      eventHandlerRef = nil
    }

    isRegistered = false
  }

  deinit {
    unregister()
  }
}
