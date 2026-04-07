import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../providers/config_provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../provider_meta.dart';
import 'oauth_url_dialog.dart';
import 'oauth_prompt_dialog.dart';

class OAuthSection extends StatefulWidget {
  final ProviderItem item;

  const OAuthSection({super.key, required this.item});

  @override
  State<OAuthSection> createState() => _OAuthSectionState();
}

class _OAuthSectionState extends State<OAuthSection> {
  bool _isLoggedIn = false;
  String _statusMsg = '';
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  bool _isDialogOpen = false;
  Timer? _pollTimer;

  String get _provider => widget.item.provider;

  @override
  void initState() {
    super.initState();
    _loadInitialStatus();
    _subscribeEvents();
  }

  @override
  void didUpdateWidget(OAuthSection old) {
    super.didUpdateWidget(old);
    if (old.item.provider != widget.item.provider) {
      _eventSub?.cancel();
      setState(() {
        _isLoggedIn = false;
        _statusMsg = '';
      });
      _loadInitialStatus();
      _subscribeEvents();
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _stopPolling();
    super.dispose();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) return;
      final cfg = Provider.of<ConfigProvider>(context, listen: false);
      final result = await cfg.getOAuthStatus(_provider);
      if (mounted && result != null && result['loggedIn'] == true) {
        setState(() {
          _isLoggedIn = true;
          _statusMsg = '✅ 로그인 완료';
          widget.item.oauthLoggedIn = true;
        });
        _closeDialog();
        _stopPolling();
      }
    });
  }

  void _closeDialog() {
    if (_isDialogOpen && mounted) {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _isDialogOpen = false;
    }
  }

  // ─── 초기 상태 로드 ───────────────────────────────────────

  Future<void> _loadInitialStatus() async {
    final cfg = Provider.of<ConfigProvider>(context, listen: false);
    final result = await cfg.getOAuthStatus(_provider);
    if (mounted && result != null) {
      setState(() => _isLoggedIn = result['loggedIn'] == true);
      widget.item.oauthLoggedIn = _isLoggedIn;
    }
  }

  // ─── /OAUTH_EVENT 구독 ────────────────────────────────────

  void _subscribeEvents() {
    _eventSub = AriAgent.on('/OAUTH_EVENT', (data) {
      if (data['provider'] != _provider || !mounted) return;
      final type = data['type'] as String?;
      if (type == null) return;

      setState(() {
        switch (type) {
          case 'auth_url':
            _statusMsg = '🌐 브라우저에서 인증을 완료하세요';
            final url = data['authUrl'] as String?;
            if (url != null) {
              // 브라우저 자동 실행 (비동기로 안전하게 실행)
              unawaited(
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                    .then((success) {
                      if (!success)
                        debugPrint('❌ Failed to launch OAuth URL: $url');
                    })
                    .catchError((e) {
                      debugPrint('❌ Error launching OAuth URL: $e');
                    }),
              );

              _isDialogOpen = true;
              showOAuthUrlDialog(
                context,
                url: url,
                instructions: data['instructions'] as String?,
              ).then((_) {
                if (mounted) _isDialogOpen = false;
              });
              _startPolling();
            }
            break;
          case 'prompt':
            _statusMsg = '✏️ 코드 입력 필요';
            final msg = data['promptMessage'] as String?;
            if (msg != null) {
              _isDialogOpen = true;
              showOAuthPromptDialog(
                context,
                provider: _provider,
                promptMessage: msg,
              ).then((_) {
                if (mounted) _isDialogOpen = false;
              });
            }
            break;
          case 'progress':
            _statusMsg = data['message'] as String? ?? '진행 중...';
            break;
          case 'done':
            _statusMsg = '✅ 로그인 완료';
            _isLoggedIn = true;
            widget.item.oauthLoggedIn = true;
            _closeDialog();
            _stopPolling();
            break;
          case 'error':
            _statusMsg = '❌ ${data['message'] ?? '오류 발생'}';
            break;
        }
      });
    });
  }

  // ─── 액션 ─────────────────────────────────────────────────

  Future<void> _login() async {
    setState(() => _statusMsg = '로그인 시작 중...');
    final cfg = Provider.of<ConfigProvider>(context, listen: false);
    await cfg.startOAuthLogin(_provider);
  }

  Future<void> _logout() async {
    final cfg = Provider.of<ConfigProvider>(context, listen: false);
    await cfg.logoutOAuth(_provider);
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _statusMsg = '';
        widget.item.oauthLoggedIn = false;
      });
    }
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상태 배지
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _isLoggedIn
                ? const Color(0xFF0D2B1A)
                : const Color(0xFF1E1A2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isLoggedIn
                  ? const Color(0xFF4ADE80).withValues(alpha: 0.4)
                  : const Color(0xFF6C63FF).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isLoggedIn ? Icons.check_circle_outline : Icons.lock_outline,
                size: 15,
                color: _isLoggedIn
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFF6C63FF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isLoggedIn
                      ? '✅ 로그인됨 (OAuth)'
                      : (_statusMsg.isEmpty ? 'OAuth 로그인이 필요합니다' : _statusMsg),
                  style: TextStyle(
                    color: _isLoggedIn
                        ? const Color(0xFF4ADE80)
                        : Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 버튼 행
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _isLoggedIn ? null : _login,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: _isLoggedIn
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
                          ),
                    color: _isLoggedIn
                        ? Colors.white.withValues(alpha: 0.06)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isLoggedIn ? Icons.check_rounded : Icons.login_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isLoggedIn ? '로그인됨' : 'OAuth 로그인',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoggedIn) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _logout,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
