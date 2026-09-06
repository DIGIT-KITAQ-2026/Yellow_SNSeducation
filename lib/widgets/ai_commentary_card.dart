import 'package:flutter/material.dart';

import '../models/child_profile.dart';
import '../services/screen_time_registry.dart';
import 'glass_card.dart';

/// 「AIによる講評」カード。ボタン押下でAI講評を取得し、結果をキャッシュ表示する。
class AiCommentaryCard extends StatelessWidget {
  final ChildProfile child;

  const AiCommentaryCard({super.key, required this.child});

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m 時点の講評';
  }

  @override
  Widget build(BuildContext context) {
    final registry = ScreenTimeRegistry.instance;
    return AnimatedBuilder(
      animation: registry,
      builder: (context, _) {
        final commentary = registry.commentaryFor(child);
        final loading = registry.isCommentaryLoading(child);
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFFF3DAE), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'AIによる講評',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (commentary == null && !loading)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF33F7FF)),
                    ),
                    onPressed: () => registry.getOrGenerateCommentary(child),
                    child: const Text('講評を見る'),
                  ),
                )
              else if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else ...[
                Text(
                  commentary!.summary,
                  style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white),
                ),
                const SizedBox(height: 12),
                ...commentary.adviceList.map(
                  (advice) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('・', style: TextStyle(color: Color(0xFF33F7FF))),
                        Expanded(
                          child: Text(
                            advice,
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _formatTime(commentary.generatedAt),
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
