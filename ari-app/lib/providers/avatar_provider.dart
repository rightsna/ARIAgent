import 'package:ari_agent/models/agent_profile.dart';
import 'package:ari_agent/repositories/profile_repository.dart';
import 'package:ari_agent/providers/server_provider.dart';

import 'package:flutter/foundation.dart';

/// AvatarProvider: UI 상태 관리를 담당하며 ProfileRepository와 직접 대화합니다.
class AvatarProvider extends ChangeNotifier {
  static final AvatarProvider _instance = AvatarProvider._internal();
  factory AvatarProvider() => _instance;
  AvatarProvider._internal();

  final ProfileRepository _repository = ProfileRepository();

  String _currentAgentId = 'default';
  bool _isInitialSynced = false;

  Future<void> init() async {
    await _repository.init();
    _currentAgentId = _repository.selectedAgentId;

    // 서버(에이전트) 시작 시 데이터 동기화 리스너 등록
    ServerProvider().addListener(_onServerStatusChanged);

    // 즉시 서버 확인
    if (ServerProvider().isRunning && !_isInitialSynced) {
      _isInitialSynced = true;
      refreshAvatars();
    }

    notifyListeners();
  }

  void _onServerStatusChanged() {
    if (ServerProvider().isRunning && !_isInitialSynced) {
      _isInitialSynced = true;
      refreshAvatars();
    } else if (!ServerProvider().isRunning) {
      _isInitialSynced = false;
    }
  }

  // 전체 아바타 목록
  List<AgentProfile> get allAvatars => _repository.getAllAgents();

  // 현재 선택된 아바타 객체
  AgentProfile get currentAvatar => _repository.getAgent(_currentAgentId);

  // 현재 선택된 아바타 ID
  String get currentAvatarId => _currentAgentId;

  // 편리한 getter
  String get name => currentAvatar.name;
  String get imagePath => currentAvatar.imagePath;
  String get persona => currentAvatar.persona;

  /// 서버로부터 목록 새로고침
  Future<void> refreshAvatars() async {
    await _repository.refreshFromServer();
    _currentAgentId = _repository.selectedAgentId;
    notifyListeners();
  }

  /// 아바타 전환
  Future<void> switchAvatar(String agentId) async {
    if (_repository.hasAgent(agentId)) {
      _currentAgentId = agentId;
      await _repository.setSelectedAgentId(agentId);
      notifyListeners();
    }
  }

  /// 새 아바타 생성 및 전환
  Future<void> createAndSwitchAvatar(String id, String newName) async {
    final newAgent = AgentProfile(id: id, name: newName, imagePath: '');
    await _repository.saveAgent(newAgent);
    await switchAvatar(id);
  }

  /// 정보 업데이트
  Future<void> updateName(String newName) async {
    await _repository.saveAgent(currentAvatar.copyWith(name: newName));
    notifyListeners();
  }

  Future<void> updateImagePath(String path) async {
    await _repository.saveAgent(currentAvatar.copyWith(imagePath: path));
    notifyListeners();
  }

  Future<void> updatePersona(String newPersona) async {
    await _repository.saveAgent(currentAvatar.copyWith(persona: newPersona));
    notifyListeners();
  }

  /// 기억 초기화
  Future<void> initializeMemory() async {
    await _repository.initializeMemory(_currentAgentId);
    notifyListeners();
  }



  /// 아바타 삭제
  Future<void> deleteAvatar() async {
    if (_currentAgentId == 'default') return;
    final idToDelete = _currentAgentId;
    await _repository.deleteAgent(idToDelete);
    _currentAgentId = _repository.selectedAgentId;
    notifyListeners();
  }

  /// 기억 데이터 가져오기
  Future<Map<String, dynamic>> getMemory() async {
    return await _repository.getMemory(_currentAgentId);
  }

  /// 장기 기억(Core) 업데이트
  Future<void> updateMemory(String content) async {
    await _repository.updateMemory(_currentAgentId, content);
  }

  @override
  void dispose() {
    ServerProvider().removeListener(_onServerStatusChanged);
    super.dispose();
  }
}
