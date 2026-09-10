import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/child_profile.dart';
import '../services/screen_time_registry.dart';
import 'glass_card.dart';
import 'robot_mascot.dart';

/// 「AIによる講評」カード。ドパガキ指数用のデータ取得はホーム画面表示時に
/// 裏側で自動的に行われるが、この講評本文は「講評を見る」を押すまで隠す。
class AiCommentaryCard extends StatefulWidget {
  final ChildProfile child;

  const AiCommentaryCard({super.key, required this.child});

  @override
  State<AiCommentaryCard> createState() => _AiCommentaryCardState();
}

class _AiCommentaryCardState extends State<AiCommentaryCard> {
  bool _revealed = false;

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
        final commentary = registry.commentaryFor(widget.child);
        final loading = registry.isCommentaryLoading(widget.child);
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
              if (!_revealed)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF33F7FF)),
                    ),
                    onPressed: () {
                      setState(() => _revealed = true);
                      registry.getOrGenerateCommentary(widget.child);
                    },
                    child: const Text('講評を見る'),
                  ),
                )
              else if (loading || commentary == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                _SpeakingCommentary(
                  summary: commentary.summary,
                  adviceList: commentary.adviceList,
                  timeLabel: _formatTime(commentary.generatedAt),
                  robotAsset: robotAssetForPercentage(commentary.dopagakiIndex.percentage),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// マスコット(仮称「ドパ」)がAI講評を喋っているように見せる吹き出し表示。
class _SpeakingCommentary extends StatelessWidget {
  final String summary;
  final List<String> adviceList;
  final String timeLabel;
  final String robotAsset;

  const _SpeakingCommentary({
    required this.summary,
    required this.adviceList,
    required this.timeLabel,
    required this.robotAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF33F7FF).withValues(alpha: 0.15),
                border: Border.all(color: const Color(0xFF33F7FF), width: 1.5),
              ),
              child: SvgPicture.asset(robotAsset),
            ),
            const SizedBox(height: 4),
            Text(
              'ドパ',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary, style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white)),
                const SizedBox(height: 12),
                ...adviceList.map(
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
                    timeLabel,
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
