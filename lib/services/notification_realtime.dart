import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import 'achievement_request_registry.dart';
import 'activity_request_registry.dart';
import 'app_session.dart';
import 'daily_notification_service.dart';
import 'exchange_request_registry.dart';
import 'notification_messages.dart';
import 'notification_registry.dart';

/// `notifications` の自分宛 INSERT を購読する。親・子どもで同じコードが動く
/// (どちらのロールでも「自分が受信者の行」を見るだけなので分岐が要らない)。
///
/// [ActivityRealtime] とは別チャンネルにしてある。あちらは
/// 「子どものやることリストを取り直す」という別の役目を持っていて、
/// 1つの `_channel` を使い回す作りのため相乗りできない。
///
/// 接続失敗・切断はアプリを止めない。失敗しても起動時取得(`auth_gate.dart`)が
/// フォールバックとして機能する。
class NotificationRealtime {
  NotificationRealtime._();

  static final NotificationRealtime instance = NotificationRealtime._();

  RealtimeChannel? _channel;

  void subscribe(String profileId) {
    unsubscribe();
    _channel = Supabase.instance.client
        .channel('notifications_$profileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: profileId,
          ),
          callback: (payload) {
            try {
              final notification = AppNotification.fromJson(payload.newRecord);
              NotificationRegistry.instance.addFromRealtime(notification);
              _applySideEffects(notification);

              // OS通知はアプリ起動中のみ・Android のみ(FCMは入れていない)。
              // 出せなくてもアプリ内のお知らせベルには載るので、失敗は無視する。
              final content = notificationContent(notification);
              unawaited(DailyNotificationService.instance.showMessage(
                title: notificationOsTitle(notification),
                body: content.title,
              ));
            } catch (err, stack) {
              debugPrint('NotificationRealtime payload handling failed: $err\n$stack');
            }
          },
        )
        .subscribe();
  }

  /// 通知の到着を、その端末の手元の状態にも反映する。親と子で見るものが
  /// 違うので、ロールで振り分ける。
  void _applySideEffects(AppNotification notification) {
    if (AppSession.instance.isChild) {
      _applyChildSideEffects(notification);
    } else {
      _applyParentSideEffects(notification);
    }
  }

  /// 親の端末に届いた申請の通知を、申請そのものの一覧にも反映する。
  ///
  /// `task_requests` / `reward_requests` の行は Realtime で配信していないので、
  /// 通知だけを受け取っても申請は手元に無い。引き直さないと、通知をタップしても
  /// 承認/却下ダイアログを開く相手が見つからず、リロードするまで承認できない。
  void _applyParentSideEffects(AppNotification notification) {
    switch (notification.kind) {
      case 'quest_request':
        unawaited(AchievementRequestRegistry.instance.refreshPending());
      case 'reward_request':
        unawaited(ExchangeRequestRegistry.instance.refreshPending());
      case 'activity_request':
        // 行そのものは ActivityRealtime が配信する。こちらは取りこぼした
        // ときの保険。
        unawaited(ActivityRequestRegistry.instance.refreshPending());
    }
  }

  /// 承認・却下の結果を、子どもの端末の手元の状態にも反映する。
  ///
  /// 判断は親の端末で走るので、通知が届いた時点が子ども側で結果を知る最初の
  /// タイミングになる。ここで申請を片付けないと「申請中」のままボタンが固まり、
  /// 却下されても再申請できない。
  void _applyChildSideEffects(AppNotification notification) {
    final profile = AppSession.instance.childProfile;
    if (profile == null) return;

    final requestId = notification.requestId;

    switch (notification.kind) {
      case 'quest_approved':
        if (requestId != null) {
          final request = AchievementRequestRegistry.instance.removeById(requestId);
          // 承認されたタスクはサーバ側で削除済み(0010)。手元からも消す。
          if (request != null) profile.questItems.remove(request.item);
        }
        _applyPointBalance(notification);

      case 'quest_rejected':
        // tasks 行は 'open' のまま残るので questItems からは消さない。
        // 申請だけ取り下げて、もう一度「達成」を押せるようにする。
        if (requestId != null) AchievementRequestRegistry.instance.removeById(requestId);

      case 'reward_approved':
        if (requestId != null) {
          final request = ExchangeRequestRegistry.instance.removeById(requestId);
          // 「常に表示」のプレゼントは承認後もカタログに残る。
          if (request != null && !request.item.alwaysVisible) {
            profile.giftItems.remove(request.item);
          }
        }
        _applyPointBalance(notification);

      case 'reward_rejected':
        if (requestId != null) ExchangeRequestRegistry.instance.removeById(requestId);

      // activity_approved でクエストが増えるぶんは ActivityRealtime が
      // tasks を取り直して反映する。ここで二重に触らない。
    }
  }

  void _applyPointBalance(AppNotification notification) {
    final balance = notification.pointBalance;
    if (balance != null) AppSession.instance.setChildPointBalance(balance);
  }

  Future<void> unsubscribe() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await Supabase.instance.client.removeChannel(channel);
    }
  }
}
