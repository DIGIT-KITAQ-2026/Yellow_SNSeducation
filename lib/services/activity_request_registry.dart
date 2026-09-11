import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/activity_request.dart';
import '../models/activity_suggestion.dart';
import '../models/child_profile.dart';
import 'activity_service.dart';
import 'child_registry.dart';
import 'notification_registry.dart';

class ActivityRequestRegistry extends ChangeNotifier {
  ActivityRequestRegistry._();

  static final ActivityRequestRegistry instance = ActivityRequestRegistry._();

  final List<ActivityRequest> _requests = [];

  List<ActivityRequest> get requests => List.unmodifiable(_requests);

  /// 同じ提案に対する二重申請を防ぐ(ボタンを「申請中」に落とすため)。
  bool hasPendingRequestFor(String? suggestionId) => suggestionId != null &&
      _requests.any((r) => r.suggestionId == suggestionId && !r.stamped);

  /// サーバが正: 親の未処理のアクティビティ申請一覧を丸ごと差し替える。[raw] は
  /// `ActivityService.fetchPendingRequests` の生タプル。各 `childId` は
  /// `ChildRegistry` から実体の [ChildProfile] を解決する(そうしないと
  /// [approve] のクエスト追加が別インスタンスに対して行われてしまうため)。
  /// [ChildRegistry.replaceGroupChildren] が先に完了している必要がある。
  void replaceAll(List<PendingActivityRequestRow> raw) {
    _requests
      ..clear()
      ..addAll([
        for (final r in raw)
          if (ChildRegistry.instance.findById(r.childId) case final profile?)
            ActivityRequest(
              id: r.id,
              childProfile: profile,
              title: r.title,
              detail: r.detail,
              suggestionId: r.suggestionId,
              createdAt: r.requestedAt,
            ),
      ]);
    notifyListeners();
  }

  Future<void> addRequest(ChildProfile childProfile, ActivitySuggestion suggestion) async {
    final requestId = await ActivityService.requestActivity(
      childId: childProfile.id!,
      title: suggestion.title,
      detail: suggestion.detail,
      suggestionId: suggestion.id,
    );
    _requests.add(ActivityRequest(
      id: requestId,
      childProfile: childProfile,
      title: suggestion.title,
      detail: suggestion.detail,
      suggestionId: suggestion.id,
    ));
    notifyListeners();
  }

  /// 親が[points]を設定して承認する。RPCが `tasks` を作って task id を返すので、
  /// その id で組み立てた [QuestItem] を questItems に楽観追加する。
  /// サーバ側の `tasks` が正で、これは画面へ即反映するための楽観更新に過ぎない。
  Future<void> approve(ActivityRequest request, int points) async {
    if (request.stamped) return;
    final created = await ActivityService.approveRequest(
      requestId: request.id!,
      points: points,
      title: request.title,
      detail: request.detail,
    );

    request.stamped = true;
    request.childProfile.questItems.add(created);
    // 子どもへの通知は approve_activity_request RPC がサーバ側で作る。ここで
    // 作ると親の端末にしか残らない(この端末には子どもは居ない)。
    unawaited(NotificationRegistry.instance.markReadByRequestId(request.id!));
    notifyListeners();
  }

  Future<void> reject(ActivityRequest request) async {
    if (request.stamped) return;
    await ActivityService.rejectRequest(request.id!);

    _requests.remove(request);
    unawaited(NotificationRegistry.instance.markReadByRequestId(request.id!));
    notifyListeners();
  }

  /// Realtime の INSERT で1件足す。既に同じ id が入っていれば無視する
  /// (起動時取得と Realtime の到着順序が前後しても二重に積まれないため)。
  void addFromRealtime(ActivityRequest request) {
    if (_requests.any((r) => r.id == request.id)) return;
    _requests.add(request);
    notifyListeners();
  }

  void clear() {
    _requests.clear();
    notifyListeners();
  }
}
