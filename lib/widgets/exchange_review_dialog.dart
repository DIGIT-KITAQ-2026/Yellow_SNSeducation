import 'package:flutter/material.dart';

import '../models/exchange_request.dart';
import '../services/exchange_request_registry.dart';

class ExchangeReviewDialog extends StatefulWidget {
  const ExchangeReviewDialog({super.key, required this.request});

  final ExchangeRequest request;

  @override
  State<ExchangeReviewDialog> createState() => _ExchangeReviewDialogState();
}

class _ExchangeReviewDialogState extends State<ExchangeReviewDialog> {
  bool _tapped = false;
  bool _submitting = false;

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      await ExchangeRequestRegistry.instance.stamp(widget.request);
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
      await ExchangeRequestRegistry.instance.reject(widget.request);
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
              '${request.childProfile.name}が${request.item.title}との交換を希望しています。'
              '交換できたら、認証スタンプを押してください。',
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
                            'assets/images/exchange_stamp.png',
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
                onPressed: _submitting ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('完了'),
              ),
            ],
            if (!request.stamped && !_tapped) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _submitting ? null : _reject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('却下'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
