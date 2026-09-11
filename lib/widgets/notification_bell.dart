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
import 'exchange_review_dialog.dart';

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

  /// 申請の通知をタップしたときに開く承認/却下ダイアログ。まだ未処理の申請が
  /// 手元にある場合だけ開き、処理済み(親が別の場所で判断した後など)なら
  /// 既読にするだけにする。
  Future<void> _openReview(AppNotification notification) async {
    final requestId = notification.requestId;
    if (requestId == null) return;

    Widget? dialog;
    switch (notification.kind) {
      case 'quest_request':
        final request = AchievementRequestRegistry.instance.requests
            .where((r) => r.id == requestId && !r.stamped)
            .firstOrNull;
        if (request != null) dialog = AchievementReviewDialog(request: request);
      case 'reward_request':
        final request = ExchangeRequestRegistry.instance.requests
            .where((r) => r.id == requestId && !r.stamped)
            .firstOrNull;
        if (request != null) dialog = ExchangeReviewDialog(request: request);
      case 'activity_request':
        final request = ActivityRequestRegistry.instance.requests
            .where((r) => r.id == requestId && !r.stamped)
            .firstOrNull;
        if (request != null) dialog = ActivityReviewDialog(request: request);
    }
    if (dialog == null) return;

    await showDialog<void>(context: context, builder: (_) => dialog!);
  }

  void _openNotifications() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final notifications = _notifications;

          Future<void> handleTap(AppNotification notification) async {
            await NotificationRegistry.instance.markRead(notification);
            await _openReview(notification);
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
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
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
                              _buildRow(notifications[i], handleTap),
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
  ) {
    final content = notificationContent(notification);
    return _NotificationRow(
      title: content.title,
      date: _formatDate(notification.createdAt),
      showCheck: notification.isRead,
      stampAssetPath: content.stampAssetPath,
      onTap: () => onTap(notification),
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
  });

  final String title;
  final String date;
  final bool showCheck;
  final String? stampAssetPath;
  final VoidCallback? onTap;

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
        ],
      ),
    );
  }
}
