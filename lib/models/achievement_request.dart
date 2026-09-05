import 'child_profile.dart';
import 'quest_item.dart';

class AchievementRequest {
  AchievementRequest({required this.childProfile, required this.item})
      : createdAt = DateTime.now();

  final ChildProfile childProfile;
  final QuestItem item;
  final DateTime createdAt;
  bool stamped = false;
}
