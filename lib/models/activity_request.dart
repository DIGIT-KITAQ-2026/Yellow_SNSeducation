import 'child_profile.dart';

/// 子どもが「行きたい」と申請した1件のアクティビティ。`title`/`detail` は
/// `activity_requests` にスナップショットされている値をそのまま持つ
/// (提案元の `activity_suggestions` 行が後で消えても内容が読める)。
class ActivityRequest {
  ActivityRequest({
    this.id,
    required this.childProfile,
    required this.title,
    this.detail = '',
    this.suggestionId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// `activity_requests.id`(SupabaseのUUID)。`approve_activity_request` /
  /// `reject_activity_request` RPC に渡すために必要。ローカル専用の
  /// ダミーでは null になりうる。
  final String? id;
  final ChildProfile childProfile;
  final String title;
  final String detail;

  /// `activity_requests.suggestion_id`。提案元の [ActivitySuggestion.id]。
  final String? suggestionId;
  final DateTime createdAt;
  bool stamped = false;
}
