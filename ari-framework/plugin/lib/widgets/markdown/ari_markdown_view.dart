import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AriMarkdownView extends StatelessWidget {
  const AriMarkdownView({
    super.key,
    required this.content,
    this.padding = const EdgeInsets.fromLTRB(18, 24, 18, 18),
    this.borderRadius = 24,
    this.primaryColor = const Color(0xFF3182F6),
    this.textMainColor = const Color(0xFF191F28),
    this.textSubColor = const Color(0xFF4E5968),
  });

  final String content;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color primaryColor;
  final Color textMainColor;
  final Color textSubColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: textMainColor,
          ),
          strong: TextStyle(
            fontWeight: FontWeight.w700,
            color: textMainColor,
          ),
          h1: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textMainColor,
          ),
          h2: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textMainColor,
          ),
          h3: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textMainColor,
          ),
          listBullet: TextStyle(color: textMainColor),
          blockquote: TextStyle(
            color: textSubColor,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
