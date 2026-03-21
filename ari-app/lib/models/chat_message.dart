class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isSystem;
  final String? requestId;

  ChatMessage({
    required this.text,
    this.isUser = true,
    this.isError = false,
    this.isSystem = false,
    this.requestId,
  });
}
