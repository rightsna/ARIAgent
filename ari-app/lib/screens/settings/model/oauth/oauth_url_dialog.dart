import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 브라우저 인증 URL 다이얼로그
Future<void> showOAuthUrlDialog(
  BuildContext context, {
  required String url,
  String? instructions,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('브라우저 인증', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (instructions != null) ...[
            Text(
              instructions,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF111122),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              url,
              style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '브라우저에서 인증을 완료하면 자동으로 진행됩니다.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: const Text(
            '브라우저 열기',
            style: TextStyle(
              color: Color(0xFF6C63FF),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('닫기', style: TextStyle(color: Colors.white38)),
        ),
      ],
    ),
  );
}
