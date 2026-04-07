import 'package:flutter/material.dart';

/// ARI 채팅 위젯의 색상/스타일 커스터마이징 설정.
///
/// 기본값은 ARIStock 디자인 시스템 기준이며, 앱마다 오버라이드 가능.
class AriChatTheme {
  final Color primaryColor;
  final Color surfaceColor;
  final Color backgroundColor;
  final Color textMain;
  final Color textSub;
  final Color borderColor;
  final double borderWidth;
  final Color hintColor;

  const AriChatTheme({
    this.primaryColor = const Color(0xFF3182F6),
    this.surfaceColor = const Color(0xFFFFFFFF),
    this.backgroundColor = const Color(0xFFF2F4F6),
    this.textMain = const Color(0xFF191F28),
    this.textSub = const Color(0xFF4E5968),
    this.borderColor = const Color(0x1A191F28),
    this.borderWidth = 1.0,
    this.hintColor = const Color(0x61191F28),
  });
}
