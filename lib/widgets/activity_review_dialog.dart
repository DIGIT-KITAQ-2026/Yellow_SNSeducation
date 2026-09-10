import 'package:flutter/material.dart';

import '../models/activity_request.dart';
import '../services/activity_request_registry.dart';
import '../utils/numeric_input_formatter.dart';

class ActivityReviewDialog extends StatefulWidget {
  const ActivityReviewDialog({super.key, required this.request});

  final ActivityRequest request;

  @override
  State<ActivityReviewDialog> createState() => _ActivityReviewDialogState();
}

class _ActivityReviewDialogState extends State<ActivityReviewDialog> {
  final _pointsController = TextEditingController(text: '30');
  bool _submitting = false;
  bool _pointsError = false;
  String _pointsErrorText = '入力されていません';

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    final text = _pointsController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _pointsError = true;
        _pointsErrorText = '入力されていません';
      });
      return;
    }
    final points = int.tryParse(text);
    // DBの制約(tasks.points > 0)と RPC の 'points must be positive' に合わせる。
    if (points == null || points <= 0) {
      setState(() {
        _pointsError = true;
        _pointsErrorText = '1以上を入力してください';
      });
      return;
    }

    setState(() => _submitting = true);
    try {
      await ActivityRequestRegistry.instance.approve(widget.request, points);
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

  Future<void> _reject() async {
    setState(() => _submitting = true);
    try {
      await ActivityRequestRegistry.instance.reject(widget.request);
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

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
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
              '${request.childProfile.name}が「${request.title}」に行きたがっています。'
              '承認するとクエストに追加されます。',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                request.detail.isEmpty ? '詳細なし' : request.detail,
                style: TextStyle(color: Colors.grey.shade800),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('設定ポイント', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 64,
                  height: 40,
                  child: TextField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [NumericInputFormatter()],
                    textAlign: TextAlign.center,
                    onChanged: (_) {
                      if (_pointsError) setState(() => _pointsError = false);
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Ｐ', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            if (_pointsError) ...[
              const SizedBox(height: 4),
              Text(
                _pointsErrorText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _approve,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('承認してクエストに追加'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _submitting ? null : _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('却下'),
            ),
          ],
        ),
      ),
    );
  }
}
