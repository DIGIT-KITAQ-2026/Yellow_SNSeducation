import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/achievement_request.dart';
import '../models/child_profile.dart';
import '../models/quest_item.dart';
import 'child_registry.dart';
import 'notification_registry.dart';
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
    // 子どもへの通知は approve_task_request RPC がサーバ側で作る。ここで
    // 作ると親の端末にしか残らない(この端末には子どもは居ない)。
    unawaited(NotificationRegistry.instance.markReadByRequestId(request.id!));
    notifyListeners();
  }

  /// 却下する。交換申請の [ExchangeRequestRegistry.reject] と同じ形。
  ///
  /// 交換と違って `questItems` からは消さない。却下では `tasks` 行が
  /// `status = 'open'` のまま残り、子どもはやり直して再申請できるため。
  Future<void> reject(AchievementRequest request) async {
    if (request.stamped) return;
    await QuestService.rejectRequest(request.id!);

    _requests.remove(request);
    unawaited(NotificationRegistry.instance.markReadByRequestId(request.id!));
    notifyListeners();
  }

  /// 子ども側で、親の判断を伝える通知を受けて手元の申請を取り下げる。
  /// 取り下げた申請を返す(承認時に対応する [QuestItem] を消すため)。
  AchievementRequest? removeById(String requestId) {
    final index = _requests.indexWhere((request) => request.id == requestId);
    if (index < 0) return null;
    final removed = _requests.removeAt(index);
    notifyListeners();
    return removed;
  }

  /// Drops every cached request. Used on sign-out (前のアカウントの申請が
  /// 通知ベルに残らないようにする)。
  void clear() {
    _requests.clear();
    notifyListeners();
  }
}
