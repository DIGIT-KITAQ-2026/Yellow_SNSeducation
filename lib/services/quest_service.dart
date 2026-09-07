import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quest_item.dart';

/// Thin wrapper over the Supabase client for everything task/quest-related
/// (`tasks` / `task_requests`). Holds no state of its own, same shape as
/// [AuthService].
class QuestService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Open (not yet completed) tasks assigned to [childId].
  static Future<List<QuestItem>> fetchTasks(String childId) async {
    final rows = await _client
        .from('tasks')
        .select('id, title, description, points')
        .eq('child_id', childId)
        .eq('status', 'open');

    return [for (final row in rows as List) QuestItem.fromJson(row as Map<String, dynamic>)];
  }

  /// Creates a task in [groupId] assigned to [childId]. `created_by` is the
  /// signed-in (parent) user, required by the `tasks_insert` RLS policy.
  static Future<QuestItem> createTask({
    required String groupId,
    required String childId,
    required String title,
    required int points,
    String detail = '',
  }) async {
    final row = await _client
        .from('tasks')
        .insert({
          'group_id': groupId,
          'child_id': childId,
          'title': title,
          'points': points,
          if (detail.isNotEmpty) 'description': detail,
          'created_by': _client.auth.currentUser!.id,
        })
        .select('id, title, description, points')
        .single();

    return QuestItem.fromJson(row);
  }

  static Future<QuestItem> updateTask(QuestItem item) async {
    final row = await _client
        .from('tasks')
        .update({
          'title': item.title,
          'points': item.points,
          'description': item.detail,
        })
        .eq('id', item.id!)
        .select('id, title, description, points')
        .single();

    return QuestItem.fromJson(row);
  }

  static Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }

  /// Submits a completion request for [taskId] on behalf of [childId].
  /// Returns the server-generated `task_requests.id`, needed later by
  /// [approveRequest] / [rejectRequest]. The caller already holds the
  /// [ChildProfile]/[QuestItem] involved, so there is no need to round-trip
  /// them back from the row.
  static Future<String> requestAchievement({
    required String taskId,
    required String childId,
  }) async {
    final row = await _client
        .from('task_requests')
        .insert({'task_id': taskId, 'child_id': childId})
        .select('id')
        .single();

    return row['id'] as String;
  }

  /// Pending (未処理) achievement requests across the whole group, for the
  /// parent's notification bell. RLS (`task_requests_select`) already limits
  /// this to the caller's own group when the caller is a parent.
  ///
  /// Returns raw `(id, childId, item)` tuples rather than a fully-formed
  /// `AchievementRequest`, because the real `ChildProfile` instance those
  /// need to mutate (see `AchievementRequestRegistry.stamp`) only exists
  /// after `ChildRegistry.replaceGroupChildren` has run — that lookup
  /// happens on the caller's side.
  static Future<List<({String id, String childId, QuestItem item})>> fetchPendingRequests(
    String groupId,
  ) async {
    final rows = await _client
        .from('task_requests')
        .select(
          'id, child_id, tasks!inner(id, title, description, points, group_id)',
        )
        .eq('status', 'pending')
        .eq('tasks.group_id', groupId);

    return [
      for (final row in rows as List)
        (
          id: row['id'] as String,
          childId: row['child_id'] as String,
          item: QuestItem.fromJson(row['tasks'] as Map<String, dynamic>),
        ),
    ];
  }

  static Future<void> approveRequest(String requestId) {
    return _client.rpc('approve_task_request', params: {'request_id': requestId});
  }

  static Future<void> rejectRequest(String requestId) {
    return _client.rpc('reject_task_request', params: {'request_id': requestId});
  }
}
