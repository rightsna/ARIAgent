import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/config_provider.dart';

/// 인증 코드 입력 다이얼로그
Future<void> showOAuthPromptDialog(
  BuildContext context, {
  required String provider,
  required String promptMessage,
}) async {
  final controller = TextEditingController();
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('코드 입력', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            promptMessage,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '코드를 입력하세요',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: const Color(0xFF111122),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            '취소',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
          ),
          onPressed: () async {
            final value = controller.text.trim();
            Navigator.of(ctx).pop();
            if (value.isNotEmpty) {
              final cfg = Provider.of<ConfigProvider>(ctx, listen: false);
              await cfg.sendOAuthPrompt(provider, value);
            }
          },
          child: const Text('확인', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
