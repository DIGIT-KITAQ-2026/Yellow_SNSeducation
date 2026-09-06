import 'package:flutter/foundation.dart';

import '../models/child_profile.dart';
import '../models/exchange_request.dart';
import '../models/gift_item.dart';
import 'child_notification_registry.dart';

class ExchangeRequestRegistry extends ChangeNotifier {
  ExchangeRequestRegistry._();

  static final ExchangeRequestRegistry instance = ExchangeRequestRegistry._();

  final List<ExchangeRequest> _requests = [];

  List<ExchangeRequest> get requests => List.unmodifiable(_requests);

  bool hasPendingRequest(GiftItem item) =>
      _requests.any((request) => request.item == item && !request.stamped);

  void addRequest(ChildProfile childProfile, GiftItem item) {
    _requests.add(ExchangeRequest(childProfile: childProfile, item: item));
    notifyListeners();
  }

  void stamp(ExchangeRequest request) {
    if (request.stamped) return;
    request.stamped = true;
    final cost = int.tryParse(request.item.points) ?? 0;
    request.childProfile.points -= cost;
    request.childProfile.giftItems.remove(request.item);
    ChildNotificationRegistry.instance.add(
      request.childProfile,
      '保護者から交換認証スタンプが押されました。${cost}Pが引かれました。',
      stampAssetPath: 'assets/images/exchange_stamp.png',
    );
    notifyListeners();
  }
}
