import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/achievement_request_registry.dart';
import '../services/activity_request_registry.dart';
import '../services/exchange_request_registry.dart';
import '../services/notification_messages.dart';
import '../services/notification_registry.dart';
import '../theme/theme_controller.dart';
import 'achievement_review_dialog.dart';
import 'activity_review_dialog.dart';
import 'confirm_delete_dialog.dart';
import 'exchange_review_dialog.dart';
import 'notification_detail_dialog.dart';

/// お知らせベル。親・子どもとも、中身はサーバの `notifications` から来る
/// 自分宛の通知一覧そのもの。
///
/// 親が申請の通知をタップしたときだけ、`request_id` から未処理の申請を引いて
/// 承認/却下ダイアログを開く。申請そのものを持っているのは従来どおり
/// [AchievementRequestRegistry] などで、ここは一覧表示だけを担う。
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    NotificationRegistry.instance.addListener(_handleChange);
    ThemeController.instance.addListener(_handleChange);
  }

  @override
  void dispose() {
    NotificationRegistry.instance.removeListener(_handleChange);
    ThemeController.instance.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() => setState(() {});

  String _formatDate(DateTime date) => '${date.month}/${date.day}';

  List<AppNotification> get _notifications => NotificationRegistry.instance.notifications;

  /// [notification] に対応する未処理の申請から承認/却下ダイアログを組み立てる。
  /// 申請系でない通知や、処理済み・手元に無い申請では null を返す。
  Widget? _buildReviewDialog(AppNotification notification, String requestId) {
    switch (notification.kind) {
      case 'quest_request':
        final request = AchievementRequestRegistry.instance.requests
            .where((r) => r.id == requestId && !r.stamped)
            .firstOrNull;
        return request == null ? null : AchievementReviewDialog(request: request);
      case 'reward_request':
        final request = ExchangeRequestRegistry.instance.requests
            .where((r) => r.id == requestId && !r.stamped)
            .firstOrNull;
        return request == null ? null : ExchangeReviewDialog(request: request);
      case 'activity_request':
        final request = ActivityRequestRegistry.instance.requests
            .where((r) => r.id == requestId && !r.stamped)
            .firstOrNull;
        return request == null ? null : ActivityReviewDialog(request: request);
      default:
        return null;
    }
  }

  /// 申請の一覧をサーバから取り直す。通知が先に届いて申請が手元に無いときの
  /// 受け皿(`NotificationRealtime` の再取得を取りこぼした場合など)。
  Future<void> _refreshRequests(AppNotification notification) {
    switch (notification.kind) {
      case 'quest_request':
        return AchievementRequestRegistry.instance.refreshPending();
      case 'reward_request':
        return ExchangeRequestRegistry.instance.refreshPending();
      case 'activity_request':
        return ActivityRequestRegistry.instance.refreshPending();
      default:
        return Future.value();
    }
  }

  /// 申請の通知をタップしたときに開く承認/却下ダイアログ。まだ未処理の申請が
  /// 手元にある場合だけ開く。手元に無ければ一度だけサーバから取り直してから
  /// もう一度探す。開けたかどうかを返す(開けなかった通知は既読にしない —
  /// スタンプを押していないのにチェックが付くのを避けるため)。
  Future<bool> _openReview(AppNotification notification) async {
    final requestId = notification.requestId;
    if (requestId == null) return false;

    var dialog = _buildReviewDialog(notification, requestId);
    if (dialog == null) {
      await _refreshRequests(notification);
      if (!mounted) return false;
      dialog = _buildReviewDialog(notification, requestId);
    }
    if (dialog == null) return false;

    await showDialog<void>(context: context, builder: (_) => dialog!);
    return true;
  }

  void _openNotifications() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final notifications = _notifications;

          // 承認/却下ダイアログを開けたときは、判断が済んだ時点で各レジストリが
          // `markReadByRequestId` で既読にする。ここで先に既読にしてしまうと、
          // まだスタンプを押していない申請にチェックが付いてしまう。
          Future<void> handleTap(AppNotification notification) async {
            final opened = await _openReview(notification);
            if (!opened) {
              // 処理済み・子ども宛の通知は「何を了承したか」を読む詳細を開く。
              await NotificationRegistry.instance.markRead(notification);
              if (!mounted) return;
              await showDialog<void>(
                context: context,
                builder: (_) => NotificationDetailDialog(notification: notification),
              );
            }
            setDialogState(() {});
          }

          Future<void> handleDelete(AppNotification notification) async {
            final confirmed = await showConfirmDeleteDialog(
              dialogContext,
              message: 'このお知らせを消去しますか？',
            );
            if (!confirmed || !mounted) return;
            try {
              await NotificationRegistry.instance.remove(notification);
            } catch (_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('通信に失敗しました。もう一度お試しください')),
              );
            }
            setDialogState(() {});
          }

          Future<void> handleDeleteAll() async {
            final confirmed = await showConfirmDeleteDialog(
              dialogContext,
              message: 'お知らせをすべて消去しますか？',
            );
            if (!confirmed || !mounted) return;
            try {
              await NotificationRegistry.instance.removeAll();
            } catch (_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('通信に失敗しました。もう一度お試しください')),
              );
            }
            setDialogState(() {});
          }

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (notifications.isNotEmpty)
                        TextButton.icon(
                          onPressed: handleDeleteAll,
                          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                          label: const Text('すべて消去'),
                          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                  Text(
                    'お知らせ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  if (notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'お知らせはありません',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < notifications.length; i++) ...[
                              if (i > 0) Divider(height: 1, color: Colors.grey.shade500),
                              _buildRow(notifications[i], handleTap, handleDelete),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow(
    AppNotification notification,
    Future<void> Function(AppNotification) onTap,
    Future<void> Function(AppNotification) onDelete,
  ) {
    final content = notificationContent(notification);
    return _NotificationRow(
      title: content.title,
      date: _formatDate(notification.createdAt),
      showCheck: notification.isRead,
      stampAssetPath: content.stampAssetPath,
      onTap: () => onTap(notification),
      onDelete: () => onDelete(notification),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeController.instance.currentPalette;
    final unreadCount = NotificationRegistry.instance.unreadCount;
    return InkWell(
      onTap: _openNotifications,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(Icons.notifications_outlined, color: palette.accent),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.title,
    required this.date,
    required this.showCheck,
    this.stampAssetPath,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final String date;
  final bool showCheck;
  final String? stampAssetPath;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(color: Colors.black87),
      ),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            date,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          if (stampAssetPath != null) ...[
            const SizedBox(width: 6),
            Image.asset(
              stampAssetPath!,
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
          ],
          if (showCheck) ...[
            const SizedBox(width: 6),
            Icon(Icons.check_circle, color: Colors.green.shade400, size: 18),
          ],
          // 一覧から直接消せる導線。スワイプ削除はこのアプリに前例が無く、
          // ListTile の onTap とも競合しないのでボタンにしてある。
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: Colors.grey.shade500,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            tooltip: 'このお知らせを消去',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
