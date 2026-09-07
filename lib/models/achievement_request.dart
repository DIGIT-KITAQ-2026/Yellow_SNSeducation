import 'child_profile.dart';
import 'quest_item.dart';

class AchievementRequest {
  AchievementRequest({this.id, required this.childProfile, required this.item})
      : createdAt = DateTime.now();

  /// `task_requests.id`(SupabaseのUUID)。`approve_task_request` /
  /// `reject_task_request` RPC に渡すために必要。ローカル専用の
  /// ダミーでは null になりうる。
  final String? id;
  final ChildProfile childProfile;
  final QuestItem item;
  final DateTime createdAt;
  bool stamped = false;
}
