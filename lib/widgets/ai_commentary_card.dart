import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/app_theme.dart';

/// 「AIによる講評」カード。ボタン押下でAI講評を取得し、結果をキャッシュ表示する。
class AiCommentaryCard extends StatelessWidget {
  final String childId;

  const AiCommentaryCard({super.key, required this.childId});

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m 時点の講評';
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final commentary = appState.commentaryFor(childId);
        final loading = appState.isCommentaryLoading(childId);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
                    SizedBox(width: 8),
                    Text('AIによる講評', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                if (commentary == null && !loading)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => appState.getOrGenerateCommentary(childId),
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
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  ...commentary.adviceList.map(
                    (advice) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('・', style: TextStyle(color: AppColors.accent)),
                          Expanded(
                            child: Text(
                              advice,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
