class AgentInfo {
  final String id;
  final String name;
  final String imagePath;
  final String description;
  final String persona;
  final List<String> skillNames;
  final List<String> appIds;

  AgentInfo({
    required this.id,
    this.name = 'ARI',
    this.imagePath = '',
    this.description = '',
    this.persona = '',
    this.skillNames = const [],
    this.appIds = const [],
  });

  AgentInfo copyWith({
    String? name,
    String? imagePath,
    String? description,
    String? persona,
    List<String>? skillNames,
    List<String>? appIds,
  }) {
    return AgentInfo(
      id: id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      description: description ?? this.description,
      persona: persona ?? this.persona,
      skillNames: skillNames ?? this.skillNames,
      appIds: appIds ?? this.appIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'description': description,
      'persona': persona,
      'skillNames': skillNames,
      'appIds': appIds,
    };
  }

  factory AgentInfo.fromMap(Map<String, dynamic> map) {
    return AgentInfo(
      id: map['id'] ?? '',
      name: map['name'] ?? 'ARI',
      imagePath: map['imagePath'] ?? '',
      description: map['description'] ?? '',
      persona: map['persona'] ?? '',
      skillNames: (map['skillNames'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      appIds: (map['appIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  Set<String> get allowedSkillNames => skillNames
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toSet();

  Set<String> get allowedAppIds => appIds
      .map((appId) => appId.trim())
      .where((appId) => appId.isNotEmpty)
      .toSet();
}
