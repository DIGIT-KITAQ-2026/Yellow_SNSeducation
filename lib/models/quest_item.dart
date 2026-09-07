class QuestItem {
  const QuestItem({
    this.id,
    required this.title,
    required this.points,
    this.detail = '',
  });

  /// `tasks.id`(SupabaseのUUID)。DB連携で作られた場合のみ入る。ローカル専用
  /// のダミー(ダイアログの一時的な戻り値等)では null になりうる。
  final String? id;
  final String title;
  final int points;
  final String detail;

  factory QuestItem.fromJson(Map<String, dynamic> json) {
    return QuestItem(
      id: json['id'] as String,
      title: json['title'] as String,
      points: json['points'] as int,
      detail: json['description'] as String? ?? '',
    );
  }

  QuestItem copyWith({String? title, int? points, String? detail}) {
    return QuestItem(
      id: id,
      title: title ?? this.title,
      points: points ?? this.points,
      detail: detail ?? this.detail,
    );
  }

  // id があるものは id で同一性を判定する(DBから再取得したリストでも
  // 編集・削除が `_items.indexOf` / `.remove` で正しく効くようにするため)。
  // id が無いローカル専用インスタンス同士は従来通りの参照同一性に委ねる。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QuestItem) return false;
    if (id == null || other.id == null) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id?.hashCode ?? identityHashCode(this);
}
