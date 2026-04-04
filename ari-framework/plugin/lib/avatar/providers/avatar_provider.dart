import 'package:ari_plugin/avatar/models/agent_profile.dart';
import 'package:ari_plugin/avatar/repositories/avatar_repository.dart';
import 'package:flutter/foundation.dart';

/// AvatarProvider: UI 상태 관리를 담당합니다.
class AvatarProvider extends ChangeNotifier {
  static final AvatarProvider _instance = AvatarProvider._internal();
  factory AvatarProvider() => _instance;
  AvatarProvider._internal();

  final AvatarRepository _repository = AvatarRepository();

  String _currentAgentId = 'default';

  Future<void> init() async {
    await _repository.init();
    _currentAgentId = _repository.selectedAgentId;
    notifyListeners();
  }

  List<AgentProfile> get allAvatars => _repository.getAllAgents();

  AgentProfile get currentAvatar => _repository.getAgent(_currentAgentId);

  String get currentAvatarId => _currentAgentId;

  String get name => currentAvatar.name;
  String get imagePath => currentAvatar.imagePath;
  String get persona => currentAvatar.persona;

  Future<void> refreshAvatars() async {
    await _repository.refreshFromServer();
    _currentAgentId = _repository.selectedAgentId;
    notifyListeners();
  }

  Future<void> switchAvatar(String agentId) async {
    if (_repository.hasAgent(agentId)) {
      _currentAgentId = agentId;
      await _repository.setSelectedAgentId(agentId);
      notifyListeners();
    }
  }

  Future<void> createAndSwitchAvatar(String id, String newName) async {
    final newAgent = AgentProfile(id: id, name: newName, imagePath: '');
    await _repository.saveAgent(newAgent);
    await switchAvatar(id);
  }

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

  Future<void> initializeMemory() async {
    await _repository.initializeMemory(_currentAgentId);
    notifyListeners();
  }

  Future<void> deleteAvatar() async {
    if (_currentAgentId == 'default') return;
    final idToDelete = _currentAgentId;
    await _repository.deleteAgent(idToDelete);
    _currentAgentId = _repository.selectedAgentId;
    notifyListeners();
  }

  Future<Map<String, dynamic>> getMemory() async {
    return await _repository.getMemory(_currentAgentId);
  }

  Future<void> updateMemory(String content) async {
    await _repository.updateMemory(_currentAgentId, content);
  }
}
