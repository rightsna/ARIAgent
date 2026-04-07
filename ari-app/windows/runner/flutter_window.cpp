#include "flutter_window.h"

#include <optional>
#include <shellapi.h>
#include <string>

#include <flutter/standard_method_codec.h>

#include "resource.h"
#include "flutter/generated_plugin_registrant.h"

namespace {

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }

  const int size_needed = MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0);
  if (size_needed <= 0) {
    return std::wstring();
  }

  std::wstring wide(static_cast<size_t>(size_needed), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(),
                      static_cast<int>(value.size()), wide.data(),
                      size_needed);
  return wide;
}

std::wstring GetStringArgument(const flutter::EncodableMap& args,
                               const char* key) {
  const auto value = args.find(flutter::EncodableValue(key));
  if (value == args.end()) {
    return std::wstring();
  }

  const auto* text = std::get_if<std::string>(&value->second);
  return text ? Utf8ToWide(*text) : std::wstring();
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  SetUpNotificationChannel();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveNotificationIcon();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_TIMER:
      if (wparam == kNotificationCleanupTimerId) {
        KillTimer(hwnd, kNotificationCleanupTimerId);
        RemoveNotificationIcon();
        return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::SetUpNotificationChannel() {
  notification_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "ari_agent/desktop_notification",
          &flutter::StandardMethodCodec::GetInstance());

  notification_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "requestPermission") {
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (call.method_name() == "showNotification") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args == nullptr) {
            result->Error("bad_args", "Notification arguments are missing.");
            return;
          }

          const std::wstring title = GetStringArgument(*args, "title");
          const std::wstring body = GetStringArgument(*args, "body");
          const bool shown = ShowDesktopNotification(title, body);
          result->Success(flutter::EncodableValue(shown));
          return;
        }

        result->NotImplemented();
      });
}

bool FlutterWindow::ShowDesktopNotification(const std::wstring& title,
                                            const std::wstring& body) {
  if (body.empty() || GetHandle() == nullptr) {
    return false;
  }

  if (!notification_icon_registered_) {
    notification_icon_data_.cbSize = sizeof(notification_icon_data_);
    notification_icon_data_.hWnd = GetHandle();
    notification_icon_data_.uID = kNotificationIconId;
    notification_icon_data_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    notification_icon_data_.uCallbackMessage = WM_APP + 1;
    notification_icon_data_.hIcon =
        LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
    wcsncpy_s(notification_icon_data_.szTip, L"ARI Agent", _TRUNCATE);

    notification_icon_registered_ =
        Shell_NotifyIconW(NIM_ADD, &notification_icon_data_) == TRUE;
    if (!notification_icon_registered_) {
      return false;
    }
  }

  notification_icon_data_.uFlags = NIF_INFO;
  wcsncpy_s(notification_icon_data_.szInfoTitle,
            title.empty() ? L"ARI Agent" : title.c_str(), _TRUNCATE);
  wcsncpy_s(notification_icon_data_.szInfo, body.c_str(), _TRUNCATE);
  notification_icon_data_.dwInfoFlags = NIIF_INFO;

  const bool modified =
      Shell_NotifyIconW(NIM_MODIFY, &notification_icon_data_) == TRUE;
  if (modified) {
    SetTimer(GetHandle(), kNotificationCleanupTimerId, 15000, nullptr);
  }
  return modified;
}

void FlutterWindow::RemoveNotificationIcon() {
  if (!notification_icon_registered_) {
    return;
  }

  Shell_NotifyIconW(NIM_DELETE, &notification_icon_data_);
  notification_icon_registered_ = false;
  ZeroMemory(&notification_icon_data_, sizeof(notification_icon_data_));
}
