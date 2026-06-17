import Foundation
import ServiceManagement

struct LaunchAtLogin {
  static func enableByDefault() {
    let key = "hasLaunchedBefore"
    if !UserDefaults.standard.bool(forKey: key) {
      do {
        try SMAppService.mainApp.register()
      } catch {
        NSLog("LaunchAtLogin: Failed to register (%@)", error.localizedDescription)
      }
      UserDefaults.standard.set(true, forKey: key)
    }
  }
}
