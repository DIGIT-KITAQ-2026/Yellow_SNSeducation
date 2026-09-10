import 'package:flutter/foundation.dart';

import '../models/achievement_request.dart';
import '../models/child_profile.dart';
import '../models/quest_item.dart';
import 'child_notification_registry.dart';
import 'child_registry.dart';
import 'quest_service.dart';

class AchievementRequestRegistry extends ChangeNotifier {
  AchievementRequestRegistry._();

  static final AchievementRequestRegistry instance =
      AchievementRequestRegistry._();

  final List<AchievementRequest> _requests = [];

  List<AchievementRequest> get requests => List.unmodifiable(_requests);

  bool hasPendingRequest(QuestItem item) => _requests
      .any((request) => request.item == item && !request.stamped);

  /// サーバが正: 親の未処理の達成申請一覧を丸ごと差し替える。[raw] は
  /// `QuestService.fetchPendingRequests` の生タプル。各 `childId` は
  /// `ChildRegistry` から実体の [ChildProfile] を解決する(そうしないと
  /// [stamp] のポイント加算が別インスタンスに対して行われてしまうため)。
  /// [ChildRegistry.replaceGroupChildren] が先に完了している必要がある。
  void replaceAll(List<({String id, String childId, QuestItem item})> raw) {
    _requests
      ..clear()
      ..addAll([
        for (final r in raw)
          if (ChildRegistry.instance.findById(r.childId) case final profile?)
            AchievementRequest(id: r.id, childProfile: profile, item: r.item),
      ]);
    notifyListeners();
  }

  Future<void> addRequest(ChildProfile childProfile, QuestItem item) async {
    final requestId = await QuestService.requestAchievement(
      taskId: item.id!,
      childId: childProfile.id!,
    );
    _requests.add(AchievementRequest(id: requestId, childProfile: childProfile, item: item));
    notifyListeners();
  }

  Future<void> stamp(AchievementRequest request) async {
    if (request.stamped) return;
    await QuestService.approveRequest(request.id!);

    request.stamped = true;
    // サーバ側の point_entries / profiles.point_balance が正。ここでの加算は
    // ダイアログを閉じた直後から画面に反映させるための楽観更新に過ぎない。
    request.childProfile.points += request.item.points;
    request.childProfile.questItems.remove(request.item);
    ChildNotificationRegistry.instance.add(
      request.childProfile,
      '保護者から達成認証スタンプが押されました。${request.item.points}Pが追加されました。',
      stampAssetPath: 'assets/images/checked_stamp.png',
    );
    notifyListeners();
  }

  /// Drops every cached request. Used on sign-out (前のアカウントの申請が
  /// 通知ベルに残らないようにする)。
  void clear() {
    _requests.clear();
    notifyListeners();
  }
}
