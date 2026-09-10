/// AIが提案した1件の周辺アクティビティ。`activity_suggestions` の1行に対応する。
class ActivitySuggestion {
  const ActivitySuggestion({
    this.id,
    required this.title,
    this.detail = '',
    this.placeName,
    this.sourceUrl,
  });

  /// `activity_suggestions.id`(SupabaseのUUID)。`activity_requests.suggestion_id`
  /// に渡すために必要。ローカル専用のダミーでは null になりうる。
  final String? id;
  final String title;
  final String detail; // activity_suggestions.description
  final String? placeName;
  final String? sourceUrl;

  factory ActivitySuggestion.fromJson(Map<String, dynamic> json) {
    return ActivitySuggestion(
      id: json['id'] as String,
      title: json['title'] as String,
      detail: json['description'] as String? ?? '',
      placeName: json['place_name'] as String?,
      sourceUrl: json['source_url'] as String?,
    );
  }

  // id があるものは id で同一性を判定する(QuestItem/GiftItem と同じ理由)。
  // id が無いローカル専用インスタンス同士は従来通りの参照同一性に委ねる。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ActivitySuggestion) return false;
    if (id == null || other.id == null) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id?.hashCode ?? identityHashCode(this);
}
