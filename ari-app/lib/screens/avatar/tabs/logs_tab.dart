import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../../../providers/avatar_provider.dart';

class LogsTab extends StatefulWidget {
  const LogsTab({super.key});

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
  final List<dynamic> _logs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _total = 0;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  String? _lastAgentId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final avatarId = context.watch<AvatarProvider>().currentAvatarId;
    if (_lastAgentId != avatarId) {
      _lastAgentId = avatarId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInitial();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _logs.clear();
      _hasMore = true;
    });

    try {
      final response = await AriAgent.call('/CHAT.GET_HISTORY', {
        'agentId': _lastAgentId,
        'index': 0,
        'size': _pageSize,
      });

      // AriAgent.call은 data 필드를 unwrap해서 반환
      final List logs = response['logs'] ?? [];
      _total = response['total'] ?? 0;
      if (mounted) {
        setState(() {
          _logs.addAll(logs);
          _hasMore = _logs.length < _total;
        });
      }
    } catch (e) {
      debugPrint('[Logs] Load failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final response = await AriAgent.call('/CHAT.GET_HISTORY', {
        'agentId': _lastAgentId,
        'index': _logs.length,
        'size': _pageSize,
      });

      final List logs = response['logs'] ?? [];
      if (mounted) {
        setState(() {
          _logs.addAll(logs);
          _hasMore = _logs.length < _total;
        });
      }
    } catch (e) {
      debugPrint('[Logs] Load more failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AvatarProvider>();

    if (_logs.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs.isEmpty) {
      return Center(
        child: Text(
          '${avatar.name}의 기록이 없습니다.',
          style: TextStyle(color: Colors.white.withOpacity(0.4)),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _logs.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _logs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final log = _logs[index];
        final isChat = log['type'] == 'chat';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isChat
                        ? (log['isUser'] == true ? '👤 USER' : '🤖 AI')
                        : '🕒 TASK: ${log['label']}',
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatTime(log['timestamp']),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isChat ? (log['message'] ?? '') : (log['result'] ?? ''),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
