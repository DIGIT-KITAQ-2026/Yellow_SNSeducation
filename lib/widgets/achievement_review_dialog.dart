import 'package:flutter/material.dart';

import '../models/achievement_request.dart';
import '../services/achievement_request_registry.dart';

class AchievementReviewDialog extends StatefulWidget {
  const AchievementReviewDialog({super.key, required this.request});

  final AchievementRequest request;

  @override
  State<AchievementReviewDialog> createState() => _AchievementReviewDialogState();
}

class _AchievementReviewDialogState extends State<AchievementReviewDialog> {
  bool _tapped = false;

  void _confirm() {
    AchievementRequestRegistry.instance.stamp(widget.request);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final showStamp = request.stamped || _tapped;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('戻る'),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              '${request.childProfile.name}が${request.item.title}の達成申請を行いました。'
              '達成したことを確認できたら、認証スタンプを押してください。',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (request.stamped || _tapped)
                      ? null
                      : () => setState(() => _tapped = true),
                  child: Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: showStamp
                        ? Image.asset(
                            'assets/images/checked_stamp.png',
                            width: 88,
                            height: 88,
                            fit: BoxFit.contain,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            if (!request.stamped && _tapped) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('完了'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
