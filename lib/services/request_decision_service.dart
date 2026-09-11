import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

/// 申請がどう決着したか。
enum RequestDecision { pending, approved, rejected }

/// 親宛の申請通知(`quest_request` など)から、その申請の結末を引くための薄い
/// ラッパー。通知の payload には申請が届いた時点の情報しか入っていないので、
/// 「何を了承したのか」は申請行を見に行かないと分からない。
///
/// 判定の根拠は 0019 で整えた申請行の寿命:
///   * 行が無い       … 却下(却下時に即削除される)
///   * status=approved … 承認済み(通知が消えるまで残る)
///   * status=pending  … まだ未処理
class RequestDecisionService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// [notification] に対応する申請テーブル名。申請系でない通知では null。
  static String? tableFor(String kind) {
    switch (kind) {
      case 'quest_request':
        return 'task_requests';
      case 'reward_request':
        return 'reward_redemptions';
      case 'activity_request':
        return 'activity_requests';
      default:
        return null;
    }
  }

  static Future<RequestDecision?> fetch(AppNotification notification) async {
    final table = tableFor(notification.kind);
    final requestId = notification.requestId;
    if (table == null || requestId == null) return null;

    final rows = await _client.from(table).select('status').eq('id', requestId).limit(1);
    if (rows.isEmpty) return RequestDecision.rejected;

    final status = rows.first['status'] as String?;
    return status == 'approved' ? RequestDecision.approved : RequestDecision.pending;
  }
}
