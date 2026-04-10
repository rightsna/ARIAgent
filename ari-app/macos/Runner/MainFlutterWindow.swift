import Cocoa
import FlutterMacOS
import UserNotifications

class MainFlutterWindow: NSWindow {
  private var notificationChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setFrameAutosaveName("MainFlutterWindow")
    self.setFrameUsingName("MainFlutterWindow")

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
