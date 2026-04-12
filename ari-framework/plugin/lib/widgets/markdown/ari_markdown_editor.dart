import 'package:flutter/material.dart';
import 'ari_markdown_diff_view.dart';
import 'ari_markdown_view.dart';

class AriMarkdownEditor extends StatelessWidget {
  const AriMarkdownEditor({
    super.key,
    required this.content,
    this.previousContent,
    this.hasDiff = false,
    required this.onApproveAll,
    required this.onRejectAll,
    required this.onPartialUpdate,
  });

  final String content;
  final String? previousContent;
  final bool hasDiff;

  final VoidCallback onApproveAll;
  final VoidCallback onRejectAll;
  final Function(String updatedContent, String updatedPrevious) onPartialUpdate;

  @override
  Widget build(BuildContext context) {
    if (hasDiff && previousContent != null) {
      return AriMarkdownDiffView(
        currentContent: content,
        previousContent: previousContent!,
        onApproveAll: onApproveAll,
        onRejectAll: onRejectAll,
        onPartialUpdate: onPartialUpdate,
      );
    }

    return AriMarkdownView(content: content);
  }
}
