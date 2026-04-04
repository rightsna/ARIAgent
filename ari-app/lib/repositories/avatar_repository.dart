import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ari_agent/models/agent_profile.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'config_repository.dart';

/// 에이전트 프로필 정보를 관리하는 레포지토리.
/// 서버(WebSocket)를 기본 데이터 소스로 사용하되, 오프라인 시 로컬 agents.json 파일을 참조합니다.
class AvatarRepository {
  final ConfigRepository _configRepository = ConfigRepository();
  Map<String, dynamic> _agentsMap = {};
  String _selectedAgentId = 'default';

  StreamSubscription? _agentsListSub;

  void cancelSubscriptions() {
    _agentsListSub?.cancel();
  }

  String get selectedAgentId => _selectedAgentId;

  File get _localAgentsFile {
    final String home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return File(p.join(home, '.ari-agent', 'agents.json'));
  }

  Directory get _imagesDir {
    final String home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return Directory(p.join(home, '.ari-agent', 'images'));
  }

  Future<void> init() async {
    await _configRepository.init();

    // 1. 우선 로컬 파일에서 캐시를 읽어옴 (서버 부팅 중에도 UI를 보여주기 위해)
    await _loadFromLocalFile();

    // 2. 기본 에이전트도 없는 경우 로컬에라도 생성
    if (_agentsMap.isEmpty) {
      final defaultAgent = AgentProfile(id: 'default', name: 'ARI');
      _agentsMap['default'] = defaultAgent.toMap();
      await _saveToLocalFile(); // 서버 켜지면 어차피 서버 파일에도 반영됨
    }

    // 3. 이미지 디렉토리 생성
    if (!await _imagesDir.exists()) {
      await _imagesDir.create(recursive: true);
    }

    // 4. 서버로부터 동기화 데이터 리스닝
    _agentsListSub = AriAgent.on('/AGENTS.LIST', (payload) {
      _updateInternalState(payload);
      _saveToLocalFile();
    });
  }

  /// 서버로부터 최신 목록 가져오기 (비동기)
  Future<void> refreshFromServer() async {
    try {
      final data = await AriAgent.call('/AGENTS');
      if (data.containsKey('agents') || data.containsKey('selected')) {
        _updateInternalState(data);
        await _saveToLocalFile(); // 로컬 캐시 갱신
      } else if (!data.containsKey('error')) {
        // 하위 호환성 (맵 형태인 경우)
        _agentsMap = data;
        await _saveToLocalFile();
      } else {
        debugPrint('[ProfileRepository] 서버 에러 수신: ${data['error']}');
      }
    } catch (e) {
      debugPrint('[ProfileRepository] 서버 통신 실패: $e');
    }
  }

  Future<void> _loadFromLocalFile() async {
    final file = _localAgentsFile;
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _updateInternalState(decoded);
          }
        }
      } catch (_) {
        _agentsMap = {};
      }
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
      // 구버전 Map 지원
      _agentsMap = data;
    }
  }

  Future<void> _saveToLocalFile() async {
    final file = _localAgentsFile;
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    try {
      final dataToSave = {
        'selected': _selectedAgentId,
        'agents': _agentsMap.values.toList(),
      };
      await file.writeAsString(jsonEncode(dataToSave));
    } catch (_) {}
  }

  List<AgentProfile> getAllAgents() {
    return _agentsMap.values
        .map((e) => AgentProfile.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  AgentProfile getAgent(String id) {
    final raw = _agentsMap[id];
    if (raw == null) return AgentProfile(id: 'default');
    return AgentProfile.fromMap(Map<String, dynamic>.from(raw));
  }

  bool hasAgent(String id) {
    return _agentsMap.containsKey(id);
  }

  // ====== Memory 관련 (추가) ======

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

  /// 아바타 이미지를 보관용 폴더(~/.ari-agent/images)로 복사
  Future<String> _processAvatarImage(String id, String rawPath) async {
    if (rawPath.isEmpty) return '';

    final sourceFile = File(rawPath);
    if (!await sourceFile.exists()) return rawPath;

    // 이미 보관 폴더 내부인 경우 건너뜀
    if (p.isWithin(_imagesDir.path, rawPath)) return rawPath;

    try {
      if (!await _imagesDir.exists()) {
        await _imagesDir.create(recursive: true);
      }

      final ext = p.extension(rawPath);
      final destPath = p.join(_imagesDir.path, '$id$ext');

      // 복사 (덮어쓰기)
      await sourceFile.copy(destPath);
      debugPrint('[ProfileRepository] Avatar image copied: $destPath');
      return destPath;
    } catch (e) {
      debugPrint('[ProfileRepository] Failed to copy avatar image: $e');
      return rawPath;
    }
  }

  Future<void> saveAgent(AgentProfile agent) async {
    // 이미지 처리 (보관 폴더로 복사)
    String processedPath = await _processAvatarImage(agent.id, agent.imagePath);
    final updatedAgent = agent.copyWith(imagePath: processedPath);

    _agentsMap[updatedAgent.id] = updatedAgent.toMap();
    // 로컬 저장
    await _saveToLocalFile();

    // 서버 저장 시도
    try {
      final dataToSave = {
        'selected': _selectedAgentId,
        'agents': _agentsMap.values.toList(),
      };
      await AriAgent.call('/AGENTS.SAVE', {'agents': dataToSave});
    } catch (e) {
      debugPrint('[ProfileRepository] 서버 저장 실패 (현재 로컬에만 저장됨): $e');
    }
  }

  Future<void> setSelectedAgentId(String id) async {
    _selectedAgentId = id;
    await _saveToLocalFile();
    try {
      await AriAgent.call('/AGENTS.SET_SELECTED', {'id': id});
    } catch (_) {}
  }

  Future<void> deleteAgent(String id) async {
    if (id == 'default') return; // 기본 에이전트는 삭제 불가 소규모 방어코드

    _agentsMap.remove(id);
    if (_selectedAgentId == id) {
      _selectedAgentId = 'default';
    }

    await _saveToLocalFile();

    // 서버 저장 시도
    try {
      final dataToSave = {
        'selected': _selectedAgentId,
        'agents': _agentsMap.values.toList(),
      };
      await AriAgent.call('/AGENTS.SAVE', {'agents': dataToSave});
      // 서버에서 명시적으로 set_selected도 호출해줌
      await AriAgent.call('/AGENTS.SET_SELECTED', {'id': _selectedAgentId});
    } catch (e) {
      debugPrint('[ProfileRepository] 서버 삭제 반영 실패: $e');
    }
  }
}
