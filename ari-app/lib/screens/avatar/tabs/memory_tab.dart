import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';

class MemoryTab extends StatefulWidget {
  const MemoryTab({super.key});

  @override
  State<MemoryTab> createState() => _MemoryTabState();
}

class _MemoryTabState extends State<MemoryTab> {
  final TextEditingController _coreMemoryController = TextEditingController();
  String _dailyLogs = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  String? _lastAvatarId;

  @override
  void initState() {
    super.initState();
    // initState에서는 context.read를 사용하여 초기 로드를 수행할 수 있지만,
    // 아바타 전환 시에는 build에서 감지하여 다시 로드하는 것이 확실합니다.
  }

  @override
  void dispose() {
    _coreMemoryController.dispose();
    super.dispose();
  }

  Future<void> _fetchMemory() async {
    // 로딩 중 중복 방지 (다만 _lastAvatarId가 바뀐 상태에서의 첫 로드는 허용)
    if (mounted) setState(() => _isLoading = true);
    try {
      final memory = await context.read<AvatarProvider>().getMemory();
      if (mounted) {
        setState(() {
          _coreMemoryController.text = memory['core'] ?? '';
          _dailyLogs = memory['daily'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('기억을 불러오는데 실패했습니다: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveCoreMemory() async {
    setState(() => _isSaving = true);
    try {
      await context.read<AvatarProvider>().updateMemory(
        _coreMemoryController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('장기 기억이 업데이트되었습니다.')));
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AvatarProvider>();

    // 아바타가 바뀌었을 때 기억 다시 불러오기
    if (_lastAvatarId != avatar.currentAvatarId) {
      _lastAvatarId = avatar.currentAvatarId;
      _isEditing = false; // 아바타 바뀌면 편집 모드 해제
      _fetchMemory();
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMemory,
      color: const Color(0xFF6C63FF),
      backgroundColor: const Color(0xFF1F1F3D),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeaderSection(
            'Core Memory',
            '에이전트의 핵심 가치관과 장기 기억입니다.',
            icon: Icons.psychology_rounded,
            action: _isEditing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _fetchMemory(); // Revert changes
                          });
                        },
                        child: const Text(
                          '취소',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF6C63FF),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _saveCoreMemory,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('저장'),
                            ),
                    ],
                  )
                : IconButton(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xFF6C63FF),
                    ),
                    tooltip: '편집하기',
                  ),
          ),
          const SizedBox(height: 16),
          _buildCoreMemoryCard(),
          const SizedBox(height: 32),
          _buildHeaderSection(
            'Recent Daily Logs',
            '최근 활동 내역 및 대화에서 생성된 일일 로그입니다.',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 16),
          _buildDailyLogsCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(
    String title,
    String subtitle, {
    required IconData icon,
    Widget? action,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildCoreMemoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isEditing
              ? const Color(0xFF6C63FF).withOpacity(0.5)
              : Colors.white.withOpacity(0.05),
          width: _isEditing ? 1.5 : 1,
        ),
      ),
      child: _isEditing
          ? TextField(
              controller: _coreMemoryController,
              maxLines: null,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
                fontFamily: 'Courier',
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '장기 기억 내용을 입력하세요...',
                hintStyle: TextStyle(color: Colors.white24),
              ),
              cursorColor: const Color(0xFF6C63FF),
            )
          : Text(
              _coreMemoryController.text.isEmpty
                  ? '아직 저장된 장기 기억이 없습니다.'
                  : _coreMemoryController.text,
              style: TextStyle(
                color: _coreMemoryController.text.isEmpty
                    ? Colors.white24
                    : Colors.white70,
                fontSize: 14,
                height: 1.6,
                fontFamily: 'Courier',
              ),
            ),
    );
  }

  Widget _buildDailyLogsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: _dailyLogs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '최근 일일 로그가 존재하지 않습니다.',
                  style: TextStyle(color: Colors.white24, fontSize: 13),
                ),
              ),
            )
          : Text(
              _dailyLogs,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.5,
                fontFamily: 'Courier',
              ),
            ),
    );
  }
}
