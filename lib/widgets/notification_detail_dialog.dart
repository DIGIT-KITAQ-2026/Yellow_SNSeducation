import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/notification_messages.dart';
import '../services/notification_registry.dart';
import '../services/request_decision_service.dart';
import 'confirm_delete_dialog.dart';

/// 処理済みの通知をタップしたときに開く詳細。承認/却下ダイアログ
/// ([AchievementReviewDialog] など)が「これから決める」画面なのに対して、
/// こちらは「何を了承した / されたか」を後から確かめるための読む画面。
///
/// 本文は通知の payload から組み立てる。ただし親宛の申請通知は payload に
/// 決着が入っていないので、[RequestDecisionService] で申請行を引いて補う。
class NotificationDetailDialog extends StatefulWidget {
  const NotificationDetailDialog({super.key, required this.notification});

  final AppNotification notification;

  @override
  State<NotificationDetailDialog> createState() => _NotificationDetailDialogState();
}

class _NotificationDetailDialogState extends State<NotificationDetailDialog> {
  RequestDecision? _decision;
  bool _loadingDecision = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (RequestDecisionService.tableFor(widget.notification.kind) != null) {
      _loadDecision();
    }
  }

  Future<void> _loadDecision() async {
    setState(() => _loadingDecision = true);
    try {
      final decision = await RequestDecisionService.fetch(widget.notification);
      if (!mounted) return;
      setState(() {
        _decision = decision;
        _loadingDecision = false;
      });
    } catch (_) {
      // 決着が引けなくても、payload だけの詳細は出せる。
      if (!mounted) return;
      setState(() => _loadingDecision = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      message: 'このお知らせを消去しますか？',
    );
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    try {
      await NotificationRegistry.instance.remove(widget.notification);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通信に失敗しました。もう一度お試しください')),
      );
    }
  }

  /// 画面の見出し。子ども宛の通知は kind だけで結末が分かる。親宛の申請通知は
  /// [_decision] が分かるまで申請が届いたことだけを出す。
  String get _headline {
    switch (widget.notification.kind) {
      case 'quest_request':
        return switch (_decision) {
          RequestDecision.approved => '達成を認証しました',
          RequestDecision.rejected => '達成申請を却下しました',
          _ => '達成申請',
        };
      case 'reward_request':
        return switch (_decision) {
          RequestDecision.approved => '交換を承認しました',
          RequestDecision.rejected => '交換申請を却下しました',
          _ => '交換申請',
        };
      case 'activity_request':
        return switch (_decision) {
          RequestDecision.approved => 'おでかけを承認しました',
          RequestDecision.rejected => 'おでかけ申請を却下しました',
          _ => 'おでかけ申請',
        };
      case 'screen_time_updated':
        return 'スクリーンタイムの更新';
      case 'quest_approved':
        return '達成が認証されました';
      case 'quest_rejected':
        return '達成申請が却下されました';
      case 'reward_approved':
        return '交換が承認されました';
      case 'reward_rejected':
        return '交換申請が却下されました';
      case 'activity_approved':
        return 'おでかけが承認されました';
      case 'activity_rejected':
        return 'おでかけ申請が却下されました';
      default:
        return 'お知らせ';
    }
  }

  String _formatDateTime(DateTime at) =>
      '${at.year}年${at.month}月${at.day}日 '
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final content = notificationContent(notification);
    final itemTitle = notification.itemTitle;
    final childName = notification.childName;
    final points = notification.points;
    final balance = notification.pointBalance;

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
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Text(
              _headline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            if (content.stampAssetPath != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Image.asset(
                  content.stampAssetPath!,
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (itemTitle != null && itemTitle.isNotEmpty)
                    _DetailRow(label: '内容', value: itemTitle),
                  if (childName != null && childName.isNotEmpty)
                    _DetailRow(label: 'お子さま', value: childName),
                  if (points != null) _DetailRow(label: 'ポイント', value: '${points}P'),
                  if (balance != null) _DetailRow(label: '残りのポイント', value: '${balance}P'),
                  _DetailRow(label: '日時', value: _formatDateTime(notification.createdAt)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loadingDecision)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  content.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            OutlinedButton(
              onPressed: _submitting ? null : _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('このお知らせを消去'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
