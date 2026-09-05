import 'dart:typed_data';

import 'gift_item.dart';
import 'quest_item.dart';

class ChildProfile {
  ChildProfile({required this.name, required this.groupCode});

  String name;
  final String groupCode;
  final List<QuestItem> questItems = [];
  final List<GiftItem> giftItems = [];
  int points = 0;
  Uint8List? avatarBytes;
}
