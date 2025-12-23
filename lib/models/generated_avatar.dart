/// Model for AI-generated avatar data
class GeneratedAvatar {
  final String id;
  final String imageBase64; // Full data URI: "data:image/png;base64,..."
  final String seed; // For consistency across story scenes
  final String style; // pixar, watercolor, cartoon, clay
  final Map<String, String> attributes; // hair_style, hair_color, skin_tone, outfit, expression
  final Map<String, dynamic>? emotionData; // Optional emotion mirroring data
  final DateTime generatedAt;

  GeneratedAvatar({
    required this.id,
    required this.imageBase64,
    required this.seed,
    required this.style,
    required this.attributes,
    this.emotionData,
    required this.generatedAt,
  });

  /// Create from API response
  factory GeneratedAvatar.fromJson(Map<String, dynamic> json) {
    return GeneratedAvatar(
      id: json['id'] as String,
      imageBase64: json['image_base64'] as String,
      seed: json['seed'] as String,
      style: json['style'] as String,
      attributes: Map<String, String>.from(json['attributes'] ?? {}),
      emotionData: json['emotion_data'] as Map<String, dynamic>?,
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }

  /// Convert to JSON for API/storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_base64': imageBase64,
      'seed': seed,
      'style': style,
      'attributes': attributes,
      'emotion_data': emotionData,
      'generated_at': generatedAt.toIso8601String(),
    };
  }

  /// Get decoded image bytes
  List<int> getImageBytes() {
    // Remove data URI prefix
    final base64String = imageBase64.split(',').last;
    return base64String.codeUnits;
  }

  /// Create a copy with updated fields
  GeneratedAvatar copyWith({
    String? id,
    String? imageBase64,
    String? seed,
    String? style,
    Map<String, String>? attributes,
    Map<String, dynamic>? emotionData,
    DateTime? generatedAt,
  }) {
    return GeneratedAvatar(
      id: id ?? this.id,
      imageBase64: imageBase64 ?? this.imageBase64,
      seed: seed ?? this.seed,
      style: style ?? this.style,
      attributes: attributes ?? this.attributes,
      emotionData: emotionData ?? this.emotionData,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}
