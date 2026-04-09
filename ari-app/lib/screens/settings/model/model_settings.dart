import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/config_provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'provider_meta.dart';
import 'provider_card.dart';
import 'widgets/add_provider_button.dart';
import 'widgets/save_button.dart';
import 'widgets/help_section.dart';
import 'widgets/server_connection_notice.dart';

class ModelSettings extends StatefulWidget {
  const ModelSettings({super.key});

  @override
  State<ModelSettings> createState() => _ModelSettingsState();
}

class _ModelSettingsState extends State<ModelSettings> {
  List<ProviderItem> _providers = [];
  bool _isSaving = false;
  String _statusMessage = '';
  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    // WS가 연결될 때만 설정 로드 (ServerProvider 로그 notifyListeners 폭발 방지)
    AriAgent.connectionNotifier.addListener(_onConnectionChanged);
    if (AriAgent.isConnected) _loadCurrentSettings();
  }

  @override
  void dispose() {
    AriAgent.connectionNotifier.removeListener(_onConnectionChanged);
    for (var p in _providers) {
      p.dispose();
    }
    super.dispose();
  }

  void _onConnectionChanged() {
    if (AriAgent.isConnected) _loadCurrentSettings();
  }

  // ─── 설정 ────────────────────────────────────────────

  Future<void> _loadCurrentSettings() async {
    final cfg = Provider.of<ConfigProvider>(context, listen: false);
    final data = await cfg.getServerHealth();

    if (data != null && mounted) {
      setState(() {
        if (data['providers'] != null &&
            (data['providers'] as List).isNotEmpty) {
          _providers = (data['providers'] as List).map((p) {
            final id = p['provider'] as String? ?? 'openai-codex';
            final meta = metaFor(id);
            final authType =
                (p['authType'] as String?) ??
                (meta.isOAuth ? 'oauth' : 'apikey');
            return ProviderItem(
              provider: id,
              model: p['model'] ?? metaFor(id).models.firstOrNull ?? '',
              hasApiKey: p['hasApiKey'] == true,
              authType: authType,
            );
          }).toList();
        } else {
          final p = (data['provider'] ?? 'openai-codex') as String;
          final m = (data['model'] ?? 'gpt-5.3-codex') as String;
          final meta = metaFor(p.isNotEmpty ? p : 'openai-codex');
          _providers = [
            ProviderItem(
              provider: p.isNotEmpty ? p : 'openai-codex',
              model: m.isNotEmpty ? m : 'gpt-5.3-codex',
              hasApiKey: data['hasApiKey'] == true,
              authType: meta.isOAuth ? 'oauth' : 'apikey',
            ),
          ];
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
      _statusMessage = '';
    });
    final cfg = Provider.of<ConfigProvider>(context, listen: false);
    final success = await cfg.saveProviders(
      _providers.map((p) => p.toJson()).toList(),
    );
    if (mounted) {
      setState(() {
        _isSaving = false;
        _statusMessage = success ? '✅ 설정 저장 완료.' : '❌ 저장 실패';
      });
    }
  }

  // ─── 목록 조작 ────────────────────────────────────────────

  void _addProvider() {
    setState(() {
      _providers.add(
        ProviderItem(
          provider: 'openai-codex',
          model: metaFor('openai-codex').models.firstOrNull?.id ?? '',
          hasApiKey: false,
          authType: 'oauth',
        ),
      );
    });
  }

  void _removeProvider(int index) {
    setState(() {
      _providers[index].dispose();
      _providers.removeAt(index);
    });
  }

  void _moveUp(int index) {
    if (index > 0) {
      setState(() => _providers.insert(index - 1, _providers.removeAt(index)));
    }
  }

  void _moveDown(int index) {
    if (index < _providers.length - 1) {
      setState(() => _providers.insert(index + 1, _providers.removeAt(index)));
    }
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_providers.isEmpty) {
      return const ServerConnectionNotice();
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI Providers (우선순위 순)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showHelp = !_showHelp),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Icon(
                          _showHelp ? Icons.help : Icons.help_outline,
                          size: 16,
                          color: _showHelp
                              ? const Color(0xFF6C63FF)
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showHelp) ...[
                  const SizedBox(height: 12),
                  const HelpSection(),
                ],
                const SizedBox(height: 16),
                ...List.generate(
                  _providers.length,
                  (i) => ProviderCard(
                    key: ValueKey('provider_${_providers[i].provider}_$i'),
                    item: _providers[i],
                    index: i,
                    totalCount: _providers.length,
                    onMoveUp: () => _moveUp(i),
                    onMoveDown: () => _moveDown(i),
                    onRemove: () => _removeProvider(i),
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(height: 12),
                AddProviderButton(onTap: _addProvider),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D1A),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusMessage(),
                const SizedBox(height: 8),
                SaveButton(isSaving: _isSaving, onTap: _saveSettings),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMessage() {
    if (_statusMessage.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _statusMessage,
        style: TextStyle(
          color: _statusMessage.startsWith('✅')
              ? const Color(0xFF4ADE80)
              : const Color(0xFFFF6B6B),
          fontSize: 12,
        ),
      ),
    );
  }
}
