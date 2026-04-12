import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// ─── 데이터 모델 및 알고리즘 ───────────────────────────────────────────────────

enum _BlockType { unchanged, added, removed, changed }

class _DiffBlock {
  _DiffBlock({
    required this.type,
    required this.originalText,
    required this.proposedText,
  });

  final _BlockType type;
  final String originalText;
  final String proposedText;
}

List<_DiffBlock> _computeBlockDiff(String oldText, String newText) {
  final oldBlocks = oldText.split('\n\n').map((e) => e.trim()).toList();
  final newBlocks = newText.split('\n\n').map((e) => e.trim()).toList();

  final m = oldBlocks.length;
  final n = newBlocks.length;

  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (oldBlocks[i - 1] == newBlocks[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
      }
    }
  }

  final rawDiff = <_DiffBlock>[];
  var i = m, j = n;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && oldBlocks[i - 1] == newBlocks[j - 1]) {
      rawDiff.add(_DiffBlock(type: _BlockType.unchanged, originalText: oldBlocks[i - 1], proposedText: oldBlocks[i - 1]));
      i--; j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      rawDiff.add(_DiffBlock(type: _BlockType.added, originalText: '', proposedText: newBlocks[j - 1]));
      j--;
    } else {
      rawDiff.add(_DiffBlock(type: _BlockType.removed, originalText: oldBlocks[i - 1], proposedText: ''));
      i--;
    }
  }

  final reversed = rawDiff.reversed.toList();
  final merged = <_DiffBlock>[];
  for (var k = 0; k < reversed.length; k++) {
    final current = reversed[k];
    if (current.type == _BlockType.removed && k + 1 < reversed.length && reversed[k + 1].type == _BlockType.added) {
      merged.add(_DiffBlock(type: _BlockType.changed, originalText: current.originalText, proposedText: reversed[k + 1].proposedText));
      k++;
    } else {
      merged.add(current);
    }
  }
  return merged;
}

// ─── 메인 뷰 ─────────────────────────────────────────────────────────────

class AriMarkdownDiffView extends StatelessWidget {
  const AriMarkdownDiffView({
    super.key,
    required this.currentContent,
    required this.previousContent,
    required this.onApproveAll,
    required this.onRejectAll,
    required this.onPartialUpdate,
    this.primaryColor = const Color(0xFF3182F6),
    this.accentGreen = const Color(0xFF2E7D32),
    this.accentRed = const Color(0xFFD32F2F),
    this.textMain = const Color(0xFF191F28),
    this.textSub = const Color(0xFF4E5968),
  });

  final String currentContent;
  final String previousContent;
  final VoidCallback onApproveAll;
  final VoidCallback onRejectAll;
  final Function(String updatedContent, String updatedPrevious) onPartialUpdate;

  final Color primaryColor;
  final Color accentGreen;
  final Color accentRed;
  final Color textMain;
  final Color textSub;

  @override
  Widget build(BuildContext context) {
    final diffBlocks = _computeBlockDiff(previousContent, currentContent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text('AI가 마크다운 수정을 제안했습니다.', style: TextStyle(fontSize: 13, color: primaryColor, fontWeight: FontWeight.bold)),
              ),
              _TopActionButton(label: '전체 거절', color: accentRed, onPressed: onRejectAll),
              _TopActionButton(label: '전체 승인', color: accentGreen, onPressed: onApproveAll),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
            border: Border.all(color: primaryColor.withOpacity(0.2)),
          ),
          child: Column(
            children: List.generate(diffBlocks.length, (idx) {
              return _DiffBlockWidget(
                block: diffBlocks[idx],
                accentGreen: accentGreen,
                accentRed: accentRed,
                primaryColor: primaryColor,
                textMain: textMain,
                textSub: textSub,
                onApprove: () => _handlePartialAction(diffBlocks, idx, true),
                onRevert: () => _handlePartialAction(diffBlocks, idx, false),
              );
            }),
          ),
        ),
      ],
    );
  }

  void _handlePartialAction(List<_DiffBlock> allBlocks, int targetIdx, bool isApprove) {
    final newProposedBlocks = <String>[];
    for (var i = 0; i < allBlocks.length; i++) {
      final block = allBlocks[i];
      if (i == targetIdx) {
        newProposedBlocks.add(isApprove ? block.proposedText : block.originalText);
      } else {
        newProposedBlocks.add(block.proposedText);
      }
    }
    final newContent = newProposedBlocks.where((s) => s.isNotEmpty).join('\n\n');

    final newOriginalBlocks = <String>[];
    for (var i = 0; i < allBlocks.length; i++) {
      final block = allBlocks[i];
      if (i == targetIdx) {
        newOriginalBlocks.add(isApprove ? block.proposedText : block.originalText);
      } else {
        newOriginalBlocks.add(block.originalText);
      }
    }
    final newPrevious = newOriginalBlocks.where((s) => s.isNotEmpty).join('\n\n');

    onPartialUpdate(newContent, newPrevious);
  }
}

class _DiffBlockWidget extends StatelessWidget {
  const _DiffBlockWidget({
    required this.block,
    required this.onApprove,
    required this.onRevert,
    required this.accentGreen,
    required this.accentRed,
    required this.primaryColor,
    required this.textMain,
    required this.textSub,
  });
  final _DiffBlock block; final VoidCallback onApprove; final VoidCallback onRevert;
  final Color accentGreen; final Color accentRed; final Color primaryColor; final Color textMain; final Color textSub;

  @override
  Widget build(BuildContext context) {
    if (block.type == _BlockType.unchanged) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: MarkdownBody(data: block.proposedText, styleSheet: _getStyle(context, textMain)));
    }
    final Color accent = block.type == _BlockType.added ? accentGreen : (block.type == _BlockType.removed ? accentRed : primaryColor);
    final String label = block.type == _BlockType.added ? '추가됨' : (block.type == _BlockType.removed ? '삭제됨' : '수정됨');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: accent.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withOpacity(0.1))),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BlockBadge(label: label, color: accent),
                const SizedBox(height: 12),
                if (block.type != _BlockType.added) _ContentBox(content: block.originalText, color: textSub, isStrike: true),
                if (block.type == _BlockType.changed) const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Icon(Icons.arrow_downward, size: 14, color: Colors.grey)),
                if (block.type != _BlockType.removed) _ContentBox(content: block.proposedText, color: textMain, isElevated: true),
              ],
            ),
          ),
          Positioned(
            top: 8, right: 8,
            child: Row(
              children: [
                _MiniButton(icon: Icons.close, color: accentRed, onTap: onRevert),
                const SizedBox(width: 6),
                _MiniButton(icon: Icons.check, color: accentGreen, onTap: onApprove),
              ],
            ),
          ),
        ],
      ),
    );
  }
  MarkdownStyleSheet _getStyle(BuildContext context, Color color, {bool strike = false}) {
    return MarkdownStyleSheet(p: TextStyle(fontSize: 13, height: 1.6, color: color, decoration: strike ? TextDecoration.lineThrough : null));
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({required this.label, required this.color, required this.onPressed});
  final String label; final Color color; final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onPressed, child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)));
  }
}

class _BlockBadge extends StatelessWidget {
  const _BlockBadge({required this.label, required this.color});
  final String label; final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)));
  }
}

class _ContentBox extends StatelessWidget {
  const _ContentBox({required this.content, required this.color, this.isStrike = false, this.isElevated = false});
  final String content; final Color color; final bool isStrike; final bool isElevated;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.1)), boxShadow: isElevated ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null),
      child: MarkdownBody(data: content, styleSheet: MarkdownStyleSheet(p: TextStyle(fontSize: 13, height: 1.5, color: color, decoration: isStrike ? TextDecoration.lineThrough : null))),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.color, required this.onTap});
  final IconData icon; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.3)), color: Colors.white), child: Icon(icon, size: 14, color: color)));
  }
}
