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
}
