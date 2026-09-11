import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import 'notification_service.dart';

/// 自分宛の通知を保持するシングルトン。ほかのレジストリと同じ
/// 「ClassName._() + static final instance + ChangeNotifier」の流儀。
///
/// 中身はサーバの `notifications` が正で、ここは起動時取得(`auth_gate`)と
/// Realtime(`NotificationRealtime`)で埋まるキャッシュ。
class NotificationRegistry extends ChangeNotifier {
  NotificationRegistry._();

  static final NotificationRegistry instance = NotificationRegistry._();

  final List<AppNotification> _notifications = [];

  /// 新しい順。
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// サーバが正: ログイン時に取得した一覧で丸ごと差し替える。
  void replaceAll(List<AppNotification> raw) {
    _notifications
      ..clear()
      ..addAll(raw);
    _sort();
    notifyListeners();
  }

  /// Realtime の INSERT で1件足す。既に同じ id が入っていれば無視する
  /// (起動時取得と Realtime の到着順序が前後しても二重に積まれないため。
  ///  [ActivityRequestRegistry.addFromRealtime] と同じ考え方)。
  void addFromRealtime(AppNotification notification) {
    if (_notifications.any((n) => n.id == notification.id)) return;
    _notifications.add(notification);
    _sort();
    notifyListeners();
  }

  /// 既読にする。画面を即座に更新したいので先にローカルを更新し、サーバへの
  /// 書き込みが失敗しても表示は壊さない(次回ログインで未読に戻るだけ)。
  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    notification.readAt = DateTime.now();
    notifyListeners();
    try {
      await NotificationService.markRead(notification.id);
    } catch (err) {
      debugPrint('NotificationRegistry.markRead failed: $err');
    }
  }

  /// [requestId] に紐づく申請系の通知をまとめて既読にする。親が承認/却下を
  /// 終えた直後に呼び、処理済みの申請がいつまでも未読バッジに残らないようにする。
  Future<void> markReadByRequestId(String requestId) async {
    final targets =
        _notifications.where((n) => !n.isRead && n.requestId == requestId).toList();
    for (final target in targets) {
      await markRead(target);
    }
  }

  /// Drops every cached notification. Used on sign-out (前のアカウントの通知が
  /// 通知ベルに残らないようにする)。
  void clear() {
    _notifications.clear();
    notifyListeners();
  }

  void _sort() => _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
