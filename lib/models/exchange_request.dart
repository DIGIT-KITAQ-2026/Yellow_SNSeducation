import 'child_profile.dart';
import 'gift_item.dart';

class ExchangeRequest {
  ExchangeRequest({required this.childProfile, required this.item})
      : createdAt = DateTime.now();

  final ChildProfile childProfile;
  final GiftItem item;
  final DateTime createdAt;
  bool stamped = false;
}
