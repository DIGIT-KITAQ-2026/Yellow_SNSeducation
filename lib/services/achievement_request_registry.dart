import 'package:flutter/foundation.dart';

import '../models/achievement_request.dart';
import '../models/child_profile.dart';
import '../models/quest_item.dart';
import 'child_notification_registry.dart';

class AchievementRequestRegistry extends ChangeNotifier {
  AchievementRequestRegistry._();

  static final AchievementRequestRegistry instance =
      AchievementRequestRegistry._();

  final List<AchievementRequest> _requests = [];

  List<AchievementRequest> get requests => List.unmodifiable(_requests);

  bool hasPendingRequest(QuestItem item) => _requests
      .any((request) => request.item == item && !request.stamped);

  void addRequest(ChildProfile childProfile, QuestItem item) {
    _requests.add(AchievementRequest(childProfile: childProfile, item: item));
    notifyListeners();
  }

  void stamp(AchievementRequest request) {
    if (request.stamped) return;
    request.stamped = true;
    final points = int.tryParse(request.item.points) ?? 0;
    request.childProfile.points += points;
    request.childProfile.questItems.remove(request.item);
    ChildNotificationRegistry.instance.add(
      request.childProfile,
      '保護者から達成認証スタンプが押されました。${points}Pが追加されました。',
      stampAssetPath: 'assets/images/checked_stamp.png',
    );
    notifyListeners();
  }
}
