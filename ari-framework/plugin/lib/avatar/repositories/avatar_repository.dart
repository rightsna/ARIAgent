import 'dart:async';
import 'package:ari_plugin/avatar/models/agent_info.dart';
import 'package:ari_plugin/bridge/ws/AriAgent.dart';
import 'package:flutter/foundation.dart';

/// 에이전트 프로필 정보를 관리하는 레포지토리.
/// 서버(WebSocket)를 기본 데이터 소스로 사용합니다.
class AvatarRepository {
  Map<String, dynamic> _agentsMap = {};
  String _selectedAgentId = 'default';

  StreamSubscription? _agentsListSub;

  void cancelSubscriptions() {
    _agentsListSub?.cancel();
  }

  String get selectedAgentId => _selectedAgentId;

  Future<void> init() async {
    _agentsListSub = AriAgent.on('/AGENTS.LIST', (payload) {
      _updateInternalState(payload);
    });
  }

  Future<void> refreshFromServer() async {
    try {
      final data = await AriAgent.call('/AGENTS');
      if (data.containsKey('agents') || data.containsKey('selected')) {
        _updateInternalState(data);
      } else if (!data.containsKey('error')) {
        _agentsMap = data;
      } else {
        debugPrint('[AvatarRepository] 서버 에러 수신: ${data['error']}');
      }
    } catch (e) {
      debugPrint('[AvatarRepository] 서버 통신 실패: $e');
    }
  }

  void _updateInternalState(Map<String, dynamic> data) {
    if (data.containsKey('agents') && data['agents'] is List) {
      final List agentsList = data['agents'];
      _agentsMap = {
        for (var item in agentsList)
          if (item is Map && item['id'] != null)
            item['id'] as String: Map<String, dynamic>.from(item),
      };
      _selectedAgentId = data['selected'] as String? ?? 'default';
    } else {
      _agentsMap = data;
    }
  }

  List<AgentInfo> getAllAgents() {
    return _agentsMap.values
        .map((e) => AgentInfo.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  AgentInfo getAgent(String id) {
    final raw = _agentsMap[id];
    if (raw == null) return AgentInfo(id: 'default');
    return AgentInfo.fromMap(Map<String, dynamic>.from(raw));
  }

  bool hasAgent(String id) {
    return _agentsMap.containsKey(id);
  }

  Future<void> initializeMemory(String agentId) async {
    try {
      await AriAgent.call('/MEMORY.CLEAR', {'agentId': agentId});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getMemory(String agentId) async {
    try {
      return await AriAgent.call('/MEMORY.GET', {'agentId': agentId});
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<void> updateMemory(String agentId, String content) async {
    try {
      await AriAgent.call('/MEMORY.UPDATE', {
        'agentId': agentId,
        'content': content,
      });
    } catch (_) {}
  }

  Future<String> _processAvatarImage(String id, String rawPath) async {
    if (rawPath.isEmpty) return '';

    try {
      final result = await AriAgent.call('/AGENTS.IMAGE.SAVE', {
        'id': id,
        'sourcePath': rawPath,
      });
      if (result['ok'] == true && result['data']?['imagePath'] != null) {
        return result['data']['imagePath'] as String;
      }
    } catch (e) {
      debugPrint('[AvatarRepository] 이미지 저장 실패: $e');
    }
    return rawPath;
  }

  Future<void> saveAgent(AgentInfo agent) async {
    String processedPath = await _processAvatarImage(agent.id, agent.imagePath);
    final updatedAgent = agent.copyWith(imagePath: processedPath);

    _agentsMap[updatedAgent.id] = updatedAgent.toMap();

    try {
      final dataToSave = {
        'selected': _selectedAgentId,
        'agents': _agentsMap.values.toList(),
      };
      await AriAgent.call('/AGENTS.SAVE', {'agents': dataToSave});
    } catch (e) {
      debugPrint('[AvatarRepository] 서버 저장 실패: $e');
    }
  }

  Future<void> setSelectedAgentId(String id) async {
    _selectedAgentId = id;
    try {
      await AriAgent.call('/AGENTS.SET_SELECTED', {'id': id});
    } catch (_) {}
  }

  Future<void> deleteAgent(String id) async {
    if (id == 'default') return;

    _agentsMap.remove(id);
    if (_selectedAgentId == id) {
      _selectedAgentId = 'default';
    }

    try {
      final dataToSave = {
        'selected': _selectedAgentId,
        'agents': _agentsMap.values.toList(),
      };
      await AriAgent.call('/AGENTS.SAVE', {'agents': dataToSave});
      await AriAgent.call('/AGENTS.SET_SELECTED', {'id': _selectedAgentId});
    } catch (e) {
      debugPrint('[AvatarRepository] 서버 삭제 반영 실패: $e');
    }
  }
}
