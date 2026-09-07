import 'dart:typed_data';

import 'gift_item.dart';
import 'quest_item.dart';

class ChildProfile {
  ChildProfile({required this.name, required this.groupCode, this.id});

  String name;
  final String groupCode;

  /// `profiles.id`(SupabaseのUUID)。Supabase連携で作られた場合のみ入る。
  /// ローカル専用のダミー作成(テスト等)では null になりうる。
  final String? id;
  final List<QuestItem> questItems = [];
  final List<GiftItem> giftItems = [];
  int points = 0;
  Uint8List? avatarBytes;
}
