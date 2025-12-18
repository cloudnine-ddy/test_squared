class SubjectModel {
  final String id;
  final String name;
  final String? iconUrl;

  const SubjectModel({
    required this.id,
    required this.name,
    this.iconUrl,
  });

  // Create from Map (e.g., from database) - Defensive with null safety
  factory SubjectModel.fromMap(Map<String, dynamic> map) {
    return SubjectModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown Subject',
      iconUrl: map['icon_url']?.toString() ?? map['iconUrl']?.toString(),
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (iconUrl != null) 'icon_url': iconUrl,
    };
  }

  // Create a copy with optional field updates
  SubjectModel copyWith({
    String? id,
    String? name,
    String? iconUrl,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconUrl: iconUrl ?? this.iconUrl,
    );
  }
}

