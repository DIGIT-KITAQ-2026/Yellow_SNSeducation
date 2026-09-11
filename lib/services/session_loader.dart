import 'dart:async';

import '../models/gift_item.dart';
import '../models/quest_item.dart';
import '../models/signup_draft.dart';
import '../models/user_profile.dart';
import 'activity_service.dart';
import 'auth_service.dart';
import 'daily_notification_service.dart';
import 'gift_service.dart';
import 'notification_service.dart';
import 'quest_service.dart';
import 'session_bridge.dart';

/// サーバからセッション一式(プロフィール・子ども一覧・保留中の申請・お知らせ)を
/// 取り直し、[SessionBridge.hydrate] でUI側の singleton に反映する。
///
/// ログイン時(`AuthGate`)と、各タブの引っ張って更新の両方がここを通る。
/// 「サーバが正」の再同期はこの1本だけにしておきたいので、画面ごとに個別の
/// 取得を書かない。
class SessionLoader {
  SessionLoader._();

  /// [isInitial] はログイン直後の1回だけ true。Realtime の購読開始と毎日のお知らせ
  /// 同期は初回だけでよく、引っ張って更新のたびにやり直すとチャンネルの張り直しと
  /// 通知の再スケジュールが無駄に走る。
  ///
  /// プロフィール行が無い場合(登録が途中で終わった場合)は null を返す。
  static Future<UserProfile?> load({bool isInitial = false}) async {
    final profile = await AuthService.fetchProfile();
    if (profile == null) return null;

    final children = await AuthService.fetchGroupChildren(profile.groupId);
    // 親のみ、通知ベルに出す未処理の達成申請・交換申請一覧をまとめて取得する。
    final isParent = profile.role == AccountRole.parent;
    final pendingRequests = isParent
        ? await QuestService.fetchPendingRequests(profile.groupId)
        : const <({String id, String childId, QuestItem item})>[];
    final pendingExchangeRequests = isParent
        ? await GiftService.fetchPendingRequests(profile.groupId)
        : const <({String id, String childId, GiftItem item})>[];
    final pendingActivityRequests = isParent
        ? await ActivityService.fetchPendingRequests()
        : const <PendingActivityRequestRow>[];
    // お知らせベルの中身。こちらは親子どちらも自分宛の行を取る。
    final notifications = await NotificationService.fetchRecent();

    SessionBridge.hydrate(
      profile: profile,
      children: children,
      pendingRequests: pendingRequests,
      pendingExchangeRequests: pendingExchangeRequests,
      pendingActivityRequests: pendingActivityRequests,
      notifications: notifications,
      email: AuthService.currentUser?.email,
      subscribeRealtime: isInitial,
    );

    if (isInitial) {
      // ログインを待たせないよう fire-and-forget。失敗しても本筋には影響しない
      // (DailyNotificationService.syncForSession が内部で例外を握っている)。
      unawaited(DailyNotificationService.instance.syncForSession(
        isChild: profile.role == AccountRole.child,
        childNames: [for (final c in children) c.name],
      ));
    }
    return profile;
  }
}
