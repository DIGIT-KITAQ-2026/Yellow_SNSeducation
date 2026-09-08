import 'child_profile.dart';
import 'gift_item.dart';

class ExchangeRequest {
  ExchangeRequest({this.id, required this.childProfile, required this.item})
      : createdAt = DateTime.now();

  /// `reward_redemptions.id`(SupabaseのUUID)。`approve_reward_request` /
  /// `reject_reward_request` RPC に渡すために必要。ローカル専用の
  /// ダミーでは null になりうる。
  final String? id;
  final ChildProfile childProfile;
  final GiftItem item;
  final DateTime createdAt;
  bool stamped = false;
}
