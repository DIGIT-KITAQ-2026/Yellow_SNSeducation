import '../models/app_notification.dart';

/// 通知の [AppNotification.kind] と payload から、画面に出す日本語と
/// 添えるスタンプ画像を組み立てる。
///
/// ウィジェットから切り離した純粋関数にしてあるのは、プラットフォーム抜きで
/// テストできるようにするため(`daily_notification_content` と同じ方針)。
({String title, String? stampAssetPath}) notificationContent(AppNotification notification) {
  final childName = notification.childName ?? 'お子さま';
  final itemTitle = notification.itemTitle ?? '';
  final points = notification.points;

  switch (notification.kind) {
    // ---- 親宛 ----
    case 'quest_request':
      return (title: '$childNameから達成申請が届きました。', stampAssetPath: null);
    case 'reward_request':
      return (title: '$childNameから交換申請が届きました。', stampAssetPath: null);
    case 'activity_request':
      return (title: '$childNameからおでかけ申請が届きました。', stampAssetPath: null);
    case 'screen_time_updated':
      return (title: '$childNameのスクリーンタイムが更新されました。', stampAssetPath: null);

    // ---- 子ども宛 ----
    case 'quest_approved':
      return (
        title: '保護者から達成認証スタンプが押されました。'
            '${points == null ? '' : '${points}Pが追加されました。'}',
        stampAssetPath: 'assets/images/checked_stamp.png',
      );
    case 'quest_rejected':
      return (title: '$itemTitleの達成申請が却下されました。', stampAssetPath: null);
    case 'reward_approved':
      return (
        title: '保護者から交換認証スタンプが押されました。'
            '${points == null ? '' : '${points}Pが引かれました。'}',
        stampAssetPath: 'assets/images/exchange_stamp.png',
      );
    case 'reward_rejected':
      return (title: '$itemTitleとの交換申請が却下されました。', stampAssetPath: null);
    case 'activity_approved':
      return (
        title: '「$itemTitle」のおでかけが承認され、クエストに追加されました。'
            '${points == null ? '' : '(${points}P)'}',
        stampAssetPath: 'assets/images/checked_stamp.png',
      );
    case 'activity_rejected':
      return (title: '「$itemTitle」のおでかけ申請は承認されませんでした。', stampAssetPath: null);

    default:
      // 将来サーバ側に kind が増えてもアプリが落ちないように、無難な文面で出す。
      return (title: '新しいお知らせがあります。', stampAssetPath: null);
  }
}

/// OS のローカル通知に使う見出し。通知バーでは本文が1行に丸められるので、
/// 誰についての通知なのかが見出しだけで分かるようにする。
String notificationOsTitle(AppNotification notification) {
  switch (notification.kind) {
    case 'quest_request':
    case 'reward_request':
    case 'activity_request':
      return '${notification.childName ?? 'お子さま'}から申請が届きました';
    case 'screen_time_updated':
      return '${notification.childName ?? 'お子さま'}のスクリーンタイム';
    default:
      return 'おうちの人からのお知らせ';
  }
}
