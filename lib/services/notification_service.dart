import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

/// `notifications` テーブルに対する薄い Supabase ラッパー。状態は持たず、
/// [QuestService] / [GiftService] と同じく static メソッドだけを並べる。
///
/// 行を作るのはサーバ側(トリガーと承認/却下RPC)だけなので、ここに insert は無い。
class NotificationService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 直近 [limit] 件の自分宛の通知を、新しい順で返す。
  /// RLS `notifications_select` が `recipient_id = auth.uid()` に絞る。
  static Future<List<AppNotification>> fetchRecent({int limit = 50}) async {
    final rows = await _client
        .from('notifications')
        .select('id, kind, child_id, payload, read_at, created_at')
        .order('created_at', ascending: false)
        .limit(limit);

    return [
      for (final row in rows as List) AppNotification.fromJson(row as Map<String, dynamic>),
    ];
  }

  static Future<void> markRead(String id) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);

  /// 1件消す。RLS `notifications_delete` が自分宛の行だけに絞る。
  ///
  /// 消えた行が申請の通知だった場合、その申請を指す通知が親子とも無くなった
  /// 時点でサーバ側のトリガーが申請行も片付ける(0019)。
  static Future<void> delete(String id) =>
      _client.from('notifications').delete().eq('id', id);

  /// 自分宛をまとめて消す。RLS `notifications_delete` があるので条件は保険だが、
  /// フィルタ無しの delete は Supabase 側で弾かれるため recipient_id で絞る。
  ///
  /// 一覧は直近50件しか取っていないので、手元に無い古い通知もここで消える。
  /// 「すべて消去」の言葉どおりで、意図した挙動。
  static Future<void> deleteAll() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return Future.value();
    return _client.from('notifications').delete().eq('recipient_id', userId);
  }
}
