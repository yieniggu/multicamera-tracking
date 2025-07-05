class Camera {
  final String id;
  final String name;
  final String description;
  final String rtspUrl;
  final String? thumbnailUrl;

  Camera({
    required this.id,
    required this.name,
    required this.description,
    required this.rtspUrl,
    this.thumbnailUrl,
  });

  Camera copyWith({
    String? name,
    String? description,
    String? rtspUrl,
    String? thumbnailUrl,
  }) {
    return Camera(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      rtspUrl: rtspUrl ?? this.rtspUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}
