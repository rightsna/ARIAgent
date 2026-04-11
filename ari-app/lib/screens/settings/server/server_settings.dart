import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/server_provider.dart';
import 'server_control_panel.dart';

class ServerSettings extends StatefulWidget {
  const ServerSettings({super.key});

  @override
  State<ServerSettings> createState() => _ServerSettingsState();
}

class _ServerSettingsState extends State<ServerSettings> {
  final TextEditingController _portController = TextEditingController();
  bool _isSaving = false;
  String _statusMessage = '';
  late ConfigProvider _configProvider;
  Timer? _modelStatusTimer;

  @override
  void initState() {
    super.initState();
    _configProvider = ConfigProvider();
    _portController.text = _configProvider.port.toString();
    _startModelStatusPollingIfNeeded();
  }

  void _startModelStatusPollingIfNeeded() {
    final status = _configProvider.embeddingModelStatus;
    if (_configProvider.useAdvancedMemory &&
        (status == 'downloading' || status == 'loading')) {
      _startPolling();
    }
  }

  void _startPolling() {
    _modelStatusTimer?.cancel();
    _modelStatusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final status = await _configProvider.refreshEmbeddingModelStatus();
      if (status == 'ready' || status == 'error') {
        _modelStatusTimer?.cancel();
        _modelStatusTimer = null;
      }
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
      _statusMessage = '';
    });

    try {
      final newPort =
          int.tryParse(_portController.text.trim()) ?? _configProvider.port;

      final success = await _configProvider.savePortToServer(newPort);
      if (success) {
        await _configProvider.setPort(newPort);
        setState(() => _statusMessage = '✅ 포트 저장 완료. (변경 시 에이전트 재시작 필요)');
      } else {
        setState(() => _statusMessage = '❌ 저장 실패 (에이전트 응답하지 않음)');
      }
    } catch (e) {
      setState(() => _statusMessage = '❌ 저장 실패');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _copyLogs(List<String> logs) async {
    if (logs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('복사할 로그가 없습니다.')));
      return;
    }

    await Clipboard.setData(ClipboardData(text: logs.join('\n')));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('로그를 복사했습니다.')));
  }

  @override
  void dispose() {
    _modelStatusTimer?.cancel();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 서버 제어 패널 (통합)
          ServerControlPanel(serverProvider: server),
          const SizedBox(height: 24),

          // 포트 설정 구역
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Server Port'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildPortInput()),
                    const SizedBox(width: 12),
                    _buildSaveButton(),
                  ],
                ),
                _buildStatusMessage(),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 에이전트 로그 (통합)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '실시간 에이전트 로그',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copyLogs(server.logs),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: Colors.white70,
                  ),
                  label: const Text(
                    '복사',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: server.logs.isEmpty
                  ? Center(
                      child: Text(
                        '아직 로그가 없습니다.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: server.logs.length,
                      reverse: true,
                      itemBuilder: (context, index) {
                        final log = server.logs[server.logs.length - 1 - index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log,
                            style: TextStyle(
                              color: log.contains('❌')
                                  ? const Color(0xFFFF6B6B)
                                  : log.contains('✅')
                                  ? const Color(0xFF4ADE80)
                                  : Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
                              fontFamily: 'Courier',
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildPortInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _portController,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: const InputDecoration(
          hintText: '29277',
          hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _saveSettings,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withOpacity(_isSaving ? 0.3 : 1.0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                '변경',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    if (_statusMessage.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        _statusMessage,
        style: TextStyle(
          color: _statusMessage.startsWith('✅')
              ? const Color(0xFF4ADE80)
              : const Color(0xFFFF6B6B),
          fontSize: 11,
        ),
      ),
    );
  }
}
