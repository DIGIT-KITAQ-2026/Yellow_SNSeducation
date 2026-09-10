import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_request.dart';
import 'activity_request_registry.dart';
import 'app_session.dart';
import 'child_registry.dart';
import 'quest_service.dart';

/// `activity_requests` の変更を購読する。プロジェクトで唯一の Realtime 利用箇所。
///
/// 親: INSERT を受けて通知ベルに即時反映する。
/// 子: 自分の申請が approved に変わったのを受けて、やることリストを取り直す
///     (承認操作は親の端末で走るため、子側は再取得しないと反映されない)。
///
/// 接続失敗・切断はアプリを止めない。失敗しても起動時取得(`auth_gate.dart`)が
/// フォールバックとして機能する。
class ActivityRealtime {
  ActivityRealtime._();

  static final ActivityRealtime instance = ActivityRealtime._();

  RealtimeChannel? _channel;

  void subscribeAsParent() {
    unsubscribe();
    // activity_requests に group_id 列が無いため、フィルタは付けられない。
    // 代わりに RLS `activity_requests_select` が同一グループの行だけを配信する。
    _channel = Supabase.instance.client
        .channel('activity_requests_parent')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activity_requests',
          callback: (payload) {
            try {
              final row = payload.newRecord;
              final childId = row['child_id'] as String?;
              final profile = childId == null ? null : ChildRegistry.instance.findById(childId);
              if (profile == null) return; // 別グループの行、または未同期の子。防御的に無視。

              ActivityRequestRegistry.instance.addFromRealtime(
                ActivityRequest(
                  id: row['id'] as String?,
                  childProfile: profile,
                  title: row['title'] as String? ?? '',
                  detail: row['description'] as String? ?? '',
                  suggestionId: row['suggestion_id'] as String?,
                  createdAt: row['requested_at'] != null
                      ? DateTime.tryParse(row['requested_at'] as String)?.toLocal()
                      : null,
                ),
              );
            } catch (err, stack) {
              debugPrint('ActivityRealtime(parent) payload handling failed: $err\n$stack');
            }
          },
        )
        .subscribe();
  }

  void subscribeAsChild(String childId) {
    unsubscribe();
    _channel = Supabase.instance.client
        .channel('activity_requests_child_$childId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'activity_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'child_id',
            value: childId,
          ),
          callback: (payload) async {
            try {
              final row = payload.newRecord;
              if (row['status'] != 'approved') return;

              final profile = AppSession.instance.childProfile;
              if (profile == null || profile.id != childId) return;

              // tasks は親端末の承認RPCで作られたばかりなので、こちらのキャッシュには
              // 無い。再取得して questItems を差し替える。
              final tasks = await QuestService.fetchTasks(childId);
              AppSession.instance.refreshChildQuests(tasks);
            } catch (err, stack) {
              debugPrint('ActivityRealtime(child) payload handling failed: $err\n$stack');
            }
          },
        )
        .subscribe();
  }

  Future<void> unsubscribe() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await Supabase.instance.client.removeChannel(channel);
    }
  }
}
