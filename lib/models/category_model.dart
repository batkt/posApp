class Category {
  final String id;
  final String baiguullagiinId;
  final String angilal;
  final List<dynamic>? dedAngilal;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category({
    required this.id,
    required this.baiguullagiinId,
    required this.angilal,
    this.dedAngilal,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id'] ?? '',
      baiguullagiinId: json['baiguullagiinId'] ?? '',
      angilal: json['angilal'] ?? '',
      dedAngilal: json['dedAngilal'] is List ? json['dedAngilal'] as List : null,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'baiguullagiinId': baiguullagiinId,
      'angilal': angilal,
      if (dedAngilal != null) 'dedAngilal': dedAngilal,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Category copyWith({
    String? id,
    String? baiguullagiinId,
    String? angilal,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      baiguullagiinId: baiguullagiinId ?? this.baiguullagiinId,
      angilal: angilal ?? this.angilal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  List<String> get subcategoryNames {
    if (dedAngilal == null) return [];
    final list = <String>[];
    for (final item in dedAngilal!) {
      if (item is String) {
        if (item.isNotEmpty) list.add(item);
      } else if (item is Map) {
        final ner = item['ner']?.toString();
        if (ner != null && ner.isNotEmpty) list.add(ner);
      }
    }
    return list;
  }

  @override
  String toString() {
    return 'Category(id: $id, angilal: $angilal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.baiguullagiinId == baiguullagiinId &&
        other.angilal == angilal;
  }

  @override
  int get hashCode {
    return id.hashCode ^ baiguullagiinId.hashCode ^ angilal.hashCode;
  }
}
