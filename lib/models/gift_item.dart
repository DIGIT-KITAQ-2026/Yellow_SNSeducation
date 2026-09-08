import 'dart:typed_data';

class GiftItem {
  const GiftItem({
    this.id,
    required this.title,
    required this.points,
    this.alwaysVisible = false,
    this.imagePath,
    this.imageBytes,
  });

  /// `rewards.id`(SupabaseのUUID)。DB連携で作られた場合のみ入る。ローカル専用
  /// のダミー(ダイアログの一時的な戻り値等)では null になりうる。
  final String? id;
  final String title;
  final int points;

  /// `rewards.always_visible`。true なら承認後もプレゼントが消えず、
  /// 繰り返し交換できる(親の編集モードでのみ切り替え可能)。
  final bool alwaysVisible;

  /// `rewards.image_path`。Supabase Storage(`gift-images` バケット)上のパス。
  /// 画像がなければ null。
  final String? imagePath;

  /// 表示用にダウンロード済み、または保存前に選択された画像の生データ。
  final Uint8List? imageBytes;

  factory GiftItem.fromJson(Map<String, dynamic> json, {Uint8List? imageBytes}) {
    return GiftItem(
      id: json['id'] as String,
      title: json['name'] as String,
      points: json['cost_points'] as int,
      alwaysVisible: json['always_visible'] as bool? ?? false,
      imagePath: json['image_path'] as String?,
      imageBytes: imageBytes,
    );
  }

  GiftItem copyWith({
    String? title,
    int? points,
    bool? alwaysVisible,
    String? imagePath,
    Uint8List? imageBytes,
  }) {
    return GiftItem(
      id: id,
      title: title ?? this.title,
      points: points ?? this.points,
      alwaysVisible: alwaysVisible ?? this.alwaysVisible,
      imagePath: imagePath ?? this.imagePath,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }

  // id があるものは id で同一性を判定する(DBから再取得したリストでも
  // 編集・削除が `_items.indexOf` / `.remove` で正しく効くようにするため)。
  // id が無いローカル専用インスタンス同士は従来通りの参照同一性に委ねる。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GiftItem) return false;
    if (id == null || other.id == null) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id?.hashCode ?? identityHashCode(this);
}
