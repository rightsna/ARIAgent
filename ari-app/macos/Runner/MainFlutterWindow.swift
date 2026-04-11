import Cocoa
import FlutterMacOS
import UserNotifications

class MainFlutterWindow: NSWindow {
  private var notificationChannel: FlutterMethodChannel?
  private let autosaveName = "MainFlutterWindow"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    restoreFrameIfPossible()
    _ = self.setFrameAutosaveName(autosaveName)

    // 투명 배경 설정
    self.isOpaque = false
    self.backgroundColor = NSColor.clear
    self.hasShadow = false
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    RegisterGeneratedPlugins(registry: flutterViewController)
    setupNotificationChannel(flutterViewController)

    super.awakeFromNib()
  }

  private func restoreFrameIfPossible() {
    let restored = self.setFrameUsingName(autosaveName)
    guard restored else {
      centerToDefaultSize()
      return
    }

    let frame = self.frame
    let minimumUsableSize = NSSize(width: 320, height: 420)
    guard frame.width >= minimumUsableSize.width,
          frame.height >= minimumUsableSize.height,
          isFrameVisible(frame) else {
      centerToDefaultSize()
      return
    }
  }

  private func centerToDefaultSize() {
    let targetSize = NSSize(width: 450, height: 720)
    let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame
    guard let visibleFrame else {
      self.setContentSize(targetSize)
      self.center()
      return
    }

    let origin = NSPoint(
      x: visibleFrame.origin.x + (visibleFrame.width - targetSize.width) / 2,
      y: visibleFrame.origin.y + (visibleFrame.height - targetSize.height) / 2
    )
    let centeredFrame = NSRect(origin: origin, size: targetSize)
    self.setFrame(centeredFrame, display: true)
  }

  private func isFrameVisible(_ frame: NSRect) -> Bool {
    NSScreen.screens.contains { screen in
      frame.intersects(screen.visibleFrame.insetBy(dx: -40, dy: -40))
    }
  }

  private func setupNotificationChannel(_ flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "ari_agent/desktop_notification",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "requestPermission":
        UNUserNotificationCenter.current().requestAuthorization(
          options: [.alert, .sound, .badge]
        ) { granted, error in
          DispatchQueue.main.async {
            if let error {
              result(
                FlutterError(
                  code: "permission_error",
                  message: "알림 권한 요청에 실패했습니다.",
                  details: error.localizedDescription
                )
              )
              return
            }
            result(granted)
          }
        }
      case "showNotification":
        guard
          let args = call.arguments as? [String: Any],
          let title = args["title"] as? String,
          let body = args["body"] as? String
        else {
          result(FlutterError(code: "bad_args", message: "잘못된 알림 인자입니다.", details: nil))
          return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
          identifier: "ari-agent-\(UUID().uuidString)",
          content: content,
          trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
          DispatchQueue.main.async {
            if let error {
              result(
                FlutterError(
                  code: "show_error",
                  message: "알림 표시에 실패했습니다.",
                  details: error.localizedDescription
                )
              )
              return
            }
            result(true)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    notificationChannel = channel
  }
}
