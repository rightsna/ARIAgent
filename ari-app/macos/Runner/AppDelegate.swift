import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let mainMenu = NSApplication.shared.mainMenu
    
    // Remove unnecessary menus: Edit (index 2), View (index 3), Window (index 4), Help (index 5)
    // Note: Indices can vary, so it's safer to check titles or remove from the end to avoid index shifts.
    // Default: [App, File, Edit, View, Window, Help]
    
    if let menu = mainMenu {
      // Remove Help
      if menu.numberOfItems > 5 { menu.removeItem(at: 5) }
      // Remove Window
      if menu.numberOfItems > 4 { menu.removeItem(at: 4) }
      // Remove View
      if menu.numberOfItems > 3 { menu.removeItem(at: 3) }
      // Remove Edit
      if menu.numberOfItems > 2 { menu.removeItem(at: 2) }
      // Remove File
      if menu.numberOfItems > 1 { menu.removeItem(at: 1) }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      if let window = sender.windows.first {
        window.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
      }
    }
    return true
  }
}
