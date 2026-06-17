import ApplicationServices
import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

  private var coordinator: AppCoordinator?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    LaunchAtLogin.enableByDefault()
    AccessibilityPermission.check()

    let persistenceService = PersistenceService()
    let clipboardService = ClipboardService(persistenceService: persistenceService)
    let monitor = PasteboardMonitor()
    let hotKeyService = HotKeyService()
    let robot = Robot()
    let statusBarController = StatusBarController()
    let historyMenuController = HistoryMenuController()

    coordinator = AppCoordinator(
      clipboardService: clipboardService,
      monitor: monitor,
      hotKeyService: hotKeyService,
      robot: robot,
      statusBarController: statusBarController,
      historyMenuController: historyMenuController
    )

    coordinator?.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    // Services will deinit and stop monitoring/unregister
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    return false
  }
}
