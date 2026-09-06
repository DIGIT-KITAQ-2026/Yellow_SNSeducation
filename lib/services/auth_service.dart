import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

/// Thin wrapper over the Supabase client for everything auth-related.
/// Holds no state of its own beyond [profileRevision].
class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
  static Session? get currentSession => _client.auth.currentSession;
  static User? get currentUser => _client.auth.currentUser;

  /// Bumped once a profile is created, so AuthGate re-runs [fetchProfile]
  /// instead of holding on to the empty result it got mid-signup.
  static final ValueNotifier<int> profileRevision = ValueNotifier(0);

  static Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Returns false when Supabase created the user but withheld a session
  /// (email confirmation is enabled on the project), in which case the profile
  /// RPCs would run unauthenticated and fail on the NOT NULL created_by.
  static Future<bool> signUp({required String email, required String password}) async {
    final response = await _client.auth.signUp(email: email, password: password);
    return response.session != null;
  }

  static Future<void> signOut() => _client.auth.signOut();

  /// Creates the group and the caller's parent profile, returning the
  /// server-generated 4-digit group code.
  static Future<String> createParentAccount({
    required String groupName,
    required String displayName,
  }) async {
    // create_parent_account RETURNS TABLE, so PostgREST hands back a list of rows.
    final rows = await _client.rpc(
      'create_parent_account',
      params: {'group_name': groupName, 'parent_display_name': displayName},
    ) as List;
    profileRevision.value++;
    return (rows.first as Map)['group_code'] as String;
  }

  /// Creates the caller's child profile inside the group owned by [code].
  static Future<void> joinGroup({
    required String code,
    required String displayName,
  }) async {
    await _client.rpc(
      'join_group',
      params: {'code': code, 'child_display_name': displayName},
    );
    profileRevision.value++;
  }

  /// The signed-in user's profile, or null when the account has no profile
  /// row yet (signup was interrupted between signUp and the RPC).
  static Future<UserProfile?> fetchProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('profiles')
        .select('id, role, display_name, point_balance, group_id, groups!inner(name, group_code)')
        .eq('id', userId)
        .maybeSingle();

    return row == null ? null : UserProfile.fromJson(row);
  }

  /// The child rows of [groupId], for the parent's 子ども切替え and the
  /// quest/gift screens. RLS (profiles_select_group) lets any group member
  /// read every profile in their own group.
  static Future<List<({String id, String name, int points})>> fetchGroupChildren(
    String groupId,
  ) async {
    final rows = await _client
        .from('profiles')
        .select('id, display_name, point_balance')
        .eq('group_id', groupId)
        .eq('role', 'child');

    return [
      for (final row in rows as List)
        (
          id: row['id'] as String,
          name: row['display_name'] as String,
          points: row['point_balance'] as int,
        ),
    ];
  }
}
