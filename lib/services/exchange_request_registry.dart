import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/child_profile.dart';
import '../models/exchange_request.dart';
import '../models/gift_item.dart';
import 'app_session.dart';
import 'child_registry.dart';
import 'gift_service.dart';
import 'notification_registry.dart';

class ExchangeRequestRegistry extends ChangeNotifier {
  ExchangeRequestRegistry._();

  static final ExchangeRequestRegistry instance = ExchangeRequestRegistry._();

  final List<ExchangeRequest> _requests = [];

  List<ExchangeRequest> get requests => List.unmodifiable(_requests);

  bool hasPendingRequest(GiftItem item) =>
      _requests.any((request) => request.item == item && !request.stamped);

  /// サーバが正: 親の未処理の交換申請一覧を丸ごと差し替える。[raw] は
  /// `GiftService.fetchPendingRequests` の生タプル。各 `childId` は
  /// `ChildRegistry` から実体の [ChildProfile] を解決する(そうしないと
  /// [stamp] のポイント減算が別インスタンスに対して行われてしまうため)。
  /// [ChildRegistry.replaceGroupChildren] が先に完了している必要がある。
  void replaceAll(List<({String id, String childId, GiftItem item})> raw) {
    _requests
      ..clear()
      ..addAll([
        for (final r in raw)
          if (ChildRegistry.instance.findById(r.childId) case final profile?)
            ExchangeRequest(id: r.id, childProfile: profile, item: r.item),
      ]);
    notifyListeners();
  }

  /// 親の手元の未処理一覧をサーバから取り直す。達成申請の
  /// [AchievementRequestRegistry.refreshPending] と同じ役目で、Realtime では
  /// 通知しか届かない交換申請を、通知をタップする前に手元へ載せる。
  Future<void> refreshPending() async {
    if (AppSession.instance.isChild) return;
    final groupId = AppSession.instance.groupId;
    if (groupId == null) return;
    try {
      replaceAll(await GiftService.fetchPendingRequests(groupId));
    } catch (err) {
      debugPrint('ExchangeRequestRegistry.refreshPending failed: $err');
    }
  }

  Future<void> addRequest(ChildProfile childProfile, GiftItem item) async {
    final requestId = await GiftService.requestExchange(rewardId: item.id!);
    _requests.add(ExchangeRequest(id: requestId, childProfile: childProfile, item: item));
    notifyListeners();
  }

  Future<void> stamp(ExchangeRequest request) async {
    if (request.stamped) return;
    await GiftService.approveRequest(request.id!);

    request.stamped = true;
    // サーバ側の point_entries / profiles.point_balance が正。ここでの減算は
    // ダイアログを閉じた直後から画面に反映させるための楽観更新に過ぎない。
    request.childProfile.points -= request.item.points;
    // 「常に表示」のプレゼントは承認後もカタログに残る(何度でも交換できる)。
    if (!request.item.alwaysVisible) {
      request.childProfile.giftItems.remove(request.item);
    }
    // 子どもへの通知は approve_reward_request RPC がサーバ側で作る。ここで
    // 作ると親の端末にしか残らない(この端末には子どもは居ない)。
    unawaited(NotificationRegistry.instance.markReadByRequestId(request.id!));
    notifyListeners();
  }

  Future<void> reject(ExchangeRequest request) async {
    if (request.stamped) return;
    await GiftService.rejectRequest(request.id!);

    _requests.remove(request);
    unawaited(NotificationRegistry.instance.markReadByRequestId(request.id!));
    notifyListeners();
  }

  /// 子ども側で、親の判断を伝える通知を受けて手元の申請を取り下げる。
  /// 取り下げた申請を返す(承認時に対応する [GiftItem] を消すため)。
  ExchangeRequest? removeById(String requestId) {
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
