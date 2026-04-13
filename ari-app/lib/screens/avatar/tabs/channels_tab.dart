import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/channel_provider.dart';
import '../widgets/tab_section_header.dart';

class ChannelsTab extends StatefulWidget {
  const ChannelsTab({super.key});

  @override
  State<ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends State<ChannelsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChannelProvider>().loadTelegram();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChannelProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabSectionHeader(
            icon: Icons.send_rounded,
            title: '채널',
            description: '에이전트가 외부와 소통하는 메시지 채널이에요.',
          ),
          if (provider.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  color: Color(0xFF6C63FF),
                  strokeWidth: 2,
                ),
              ),
            )
          else
            _TelegramCard(state: provider.telegram),
        ],
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Telegram Card
// ─────────────────────────────────────────────────────────────────────────────

class _TelegramCard extends StatefulWidget {
  final TelegramChannelState state;

  const _TelegramCard({required this.state});

  @override
  State<_TelegramCard> createState() => _TelegramCardState();
}

class _TelegramCardState extends State<_TelegramCard> {
  bool _expanded = false;
  final _tokenController = TextEditingController();
  bool _tokenObscured = true;
  bool _isTesting = false;
  bool _isSaving = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    // 토큰이 저장된 상태면 기본으로 펼쳐두기 (필드는 항상 비워둠)
    if (widget.state.hasToken) _expanded = true;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  bool get _tokenIsNew {
    final t = _tokenController.text.trim();
    return t.isNotEmpty;
  }

  // 간단한 토큰 형식 검증: "숫자:문자열"
  bool _isValidTokenFormat(String token) {
    return RegExp(r'^\d+:[A-Za-z0-9_-]+$').hasMatch(token);
  }

  Future<void> _onTest() async {
    final token = _tokenController.text.trim();

    // 새로 입력된 토큰이 있으면 그걸로, 없으면 저장된 토큰을 서버에서 사용
    if (token.isNotEmpty && !_isValidTokenFormat(token)) {
      _showSnack('토큰 형식이 올바르지 않습니다. (예: 123456:ABCdef)', isError: true);
      return;
    }
    if (token.isEmpty && !widget.state.hasToken) {
      _showSnack('Bot Token을 먼저 입력하세요.', isError: true);
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final result = await context.read<ChannelProvider>().testTelegram(token);
    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _testOk = result['ok'] == true;
      _testResult = _testOk
          ? '@${result['botName'] ?? 'unknown'} 연결 성공'
          : (result['message'] as String? ?? '연결 실패');
    });
  }

  Future<void> _onSave() async {
    setState(() => _isSaving = true);

    final provider = context.read<ChannelProvider>();
    final newToken = _tokenIsNew ? _tokenController.text.trim() : null;

    final ok = await provider.saveTelegram(
      botToken: newToken,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    _showSnack(ok ? '저장되었습니다.' : '저장 실패', isError: !ok);
  }

  Future<void> _onToggle(bool value) async {
    final provider = context.read<ChannelProvider>();

    if (value && !widget.state.hasToken && !_tokenIsNew) {
      _showSnack('Bot Token을 먼저 저장하세요.', isError: true);
      return;
    }

    // 새 토큰 입력된 상태면 먼저 저장
    if (value && _tokenIsNew) {
      await _onSave();
    }

    final ok = await provider.toggleTelegram(value);
    if (!mounted) return;
    if (!ok) {
      _showSnack(provider.errorMessage ?? '오류가 발생했습니다.', isError: true);
      provider.clearError();
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFFF6B6B) : const Color(0xFF6C63FF),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // ── 헤더 (항상 표시) ──
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('✈️', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Telegram',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.enabled
                              ? (state.isPolling ? '● 연결 중' : '● 시작 중...')
                              : (state.hasToken ? '연결 준비됨' : '설정 필요'),
                          style: TextStyle(
                            color: state.enabled
                                ? const Color(0xFF4CAF50)
                                : Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 토글
                  Transform.scale(
                    scale: 0.65,
                    child: Switch(
                      value: state.enabled,
                      onChanged: _onToggle,
                      activeThumbColor: const Color(0xFF6C63FF),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white24,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── 펼쳐지는 설정 ──
          if (_expanded) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bot Token
                  Row(
                    children: [
                      _label('Bot Token'),
                      if (state.hasToken) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '저장됨',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (state.hasToken && !_tokenIsNew)
                    Text(
                      '${state.botTokenMasked}  •  변경하려면 아래에 새 토큰을 입력하세요.',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tokenController,
                          obscureText: _tokenObscured,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                          decoration: _inputDecoration(
                            hint: state.hasToken
                                ? '새 토큰 입력 (변경 시)'
                                : '123456:ABC-DEF...',
                            suffix: IconButton(
                              icon: Icon(
                                _tokenObscured
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 16,
                                color: Colors.white38,
                              ),
                              onPressed: () => setState(
                                  () => _tokenObscured = !_tokenObscured),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _outlinedButton(
                        label: _isTesting ? '...' : '테스트',
                        onTap: _isTesting ? null : _onTest,
                      ),
                    ],
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          _testOk
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          size: 13,
                          color: _testOk
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF6B6B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _testResult!,
                          style: TextStyle(
                            fontSize: 11,
                            color: _testOk
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF6B6B),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '저장',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
      ),
    );
  }

  Widget _outlinedButton({
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: onTap == null
                ? Colors.white12
                : const Color(0xFF6C63FF).withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onTap == null ? Colors.white24 : const Color(0xFF6C63FF),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

}
