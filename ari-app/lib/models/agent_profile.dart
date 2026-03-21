class AgentProfile {
  final String id;
  final String name;
  final String imagePath;
  final String description;
  final String persona;

  AgentProfile({
    required this.id,
    this.name = 'ARI',
    this.imagePath = '',
    this.description = '',
    this.persona = '',
  });

  AgentProfile copyWith({
    String? name,
    String? imagePath,
    String? description,
    String? persona,
  }) {
    return AgentProfile(
      id: id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      description: description ?? this.description,
      persona: persona ?? this.persona,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'description': description,
      'persona': persona,
    };
  }

  factory AgentProfile.fromMap(Map<String, dynamic> map) {
    return AgentProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? 'ARI',
      imagePath: map['imagePath'] ?? '',
      description: map['description'] ?? '',
      persona: map['persona'] ?? '',
    );
  }
}
