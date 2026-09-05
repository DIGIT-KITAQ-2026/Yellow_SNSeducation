import 'signup_draft.dart';

/// A signed-in user's `profiles` row joined with the `groups` row it belongs to.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    required this.displayName,
    required this.pointBalance,
    required this.groupId,
    required this.groupName,
    required this.groupCode,
  });

  final String id;
  final AccountRole role;
  final String displayName;
  final int pointBalance;
  final String groupId;
  final String groupName;
  final String groupCode;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final group = json['groups'] as Map<String, dynamic>;
    return UserProfile(
      id: json['id'] as String,
      role: json['role'] == 'parent' ? AccountRole.parent : AccountRole.child,
      displayName: json['display_name'] as String,
      pointBalance: json['point_balance'] as int,
      groupId: json['group_id'] as String,
      groupName: group['name'] as String,
      groupCode: group['group_code'] as String,
    );
  }
}
