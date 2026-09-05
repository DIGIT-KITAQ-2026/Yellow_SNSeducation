import 'package:flutter/material.dart';

import '../models/achievement_request.dart';
import '../models/child_notification.dart';
import '../models/exchange_request.dart';
import '../services/achievement_request_registry.dart';
import '../services/app_session.dart';
import '../services/child_notification_registry.dart';
import '../services/exchange_request_registry.dart';
import 'achievement_review_dialog.dart';
import 'exchange_review_dialog.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    AchievementRequestRegistry.instance.addListener(_handleChange);
    ExchangeRequestRegistry.instance.addListener(_handleChange);
    ChildNotificationRegistry.instance.addListener(_handleChange);
  }

  @override
  void dispose() {
    AchievementRequestRegistry.instance.removeListener(_handleChange);
    ExchangeRequestRegistry.instance.removeListener(_handleChange);
    ChildNotificationRegistry.instance.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() => setState(() {});

  String _formatDate(DateTime date) => '${date.month}/${date.day}';

  List<AchievementRequest> get _achievementRequests =>
      AchievementRequestRegistry.instance.requests;

  List<ExchangeRequest> get _exchangeRequests =>
      ExchangeRequestRegistry.instance.requests;

  List<ChildNotification> get _childNotifications {
    final childProfile = AppSession.instance.childProfile;
    return ChildNotificationRegistry.instance.notifications
        .where((n) => n.childProfile == childProfile)
        .toList();
  }

  void _openParentNotifications() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final achievementRequests = _achievementRequests;
          final exchangeRequests = _exchangeRequests;

          Future<void> openAchievement(AchievementRequest request) async {
            await showDialog<void>(
              context: context,
              builder: (_) => AchievementReviewDialog(request: request),
            );
            setDialogState(() {});
          }

          Future<void> openExchange(ExchangeRequest request) async {
            await showDialog<void>(
              context: context,
              builder: (_) => ExchangeReviewDialog(request: request),
            );
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
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (achievementRequests.isEmpty && exchangeRequests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'お知らせはありません',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    )
                  else ...[
                    for (final row in [
                      ...achievementRequests.map(
                        (request) => _NotificationRow(
                          title: '${request.childProfile.name}から達成申請をされました。',
                          date: _formatDate(request.createdAt),
                          showCheck: request.stamped,
                          onTap: () => openAchievement(request),
                        ),
                      ),
                      ...exchangeRequests.map(
                        (request) => _NotificationRow(
                          title: '${request.childProfile.name}から交換申請をされました。',
                          date: _formatDate(request.createdAt),
                          showCheck: request.stamped,
                          onTap: () => openExchange(request),
                        ),
                      ),
                    ].asMap().entries) ...[
                      if (row.key > 0) Divider(height: 1, color: Colors.grey.shade500),
                      row.value,
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openChildNotifications() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final notifications = _childNotifications;

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
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (notifications.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'お知らせはありません',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < notifications.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: Colors.grey.shade500),
                      _NotificationRow(
                        title: notifications[i].message,
                        date: _formatDate(notifications[i].createdAt),
                        showCheck: notifications[i].read,
                        stampAssetPath: notifications[i].stampAssetPath,
                        onTap: () {
                          ChildNotificationRegistry.instance.markRead(notifications[i]);
                          setDialogState(() {});
                        },
                      ),
                    ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isChild = AppSession.instance.isChild;
    final unreadCount = isChild
        ? _childNotifications.where((n) => !n.read).length
        : _achievementRequests.where((r) => !r.stamped).length +
            _exchangeRequests.where((r) => !r.stamped).length;
    return InkWell(
      onTap: isChild ? _openChildNotifications : _openParentNotifications,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(Icons.notifications_outlined, color: Color(0xFF33F7FF)),
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
      title: Text(title),
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
