import 'package:flutter/foundation.dart';

import '../models/child_profile.dart';
import '../models/exchange_request.dart';
import '../models/gift_item.dart';
import 'child_notification_registry.dart';
import 'child_registry.dart';
import 'gift_service.dart';

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
    ChildNotificationRegistry.instance.add(
      request.childProfile,
      '保護者から交換認証スタンプが押されました。${request.item.points}Pが引かれました。',
      stampAssetPath: 'assets/images/exchange_stamp.png',
    );
    notifyListeners();
  }

  Future<void> reject(ExchangeRequest request) async {
    if (request.stamped) return;
    await GiftService.rejectRequest(request.id!);

    _requests.remove(request);
    ChildNotificationRegistry.instance.add(
      request.childProfile,
      '${request.item.title}との交換申請が却下されました。',
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
