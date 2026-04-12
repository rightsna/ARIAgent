/// 채팅 메시지 데이터 모델.
class AriChatMessage {
  final String text;
  final bool isUser;
  final bool isSystem;
  final bool isNotice;
  final bool isError;
  final DateTime createdAt;
  final String? requestId;

  AriChatMessage({
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.isSystem = false,
    this.isNotice = false,
    this.isError = false,
    this.requestId,
  });
}
