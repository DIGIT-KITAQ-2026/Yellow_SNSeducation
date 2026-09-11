import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/child_profile.dart';
import '../services/screen_time_registry.dart';
import '../theme/app_palette.dart';
import '../theme/theme_controller.dart';
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
      animation: Listenable.merge([registry, ThemeController.instance]),
      builder: (context, _) {
        final palette = ThemeController.instance.currentPalette;
        final commentary = registry.commentaryFor(widget.child);
        final loading = registry.isCommentaryLoading(widget.child);
        final error = registry.commentaryErrorFor(widget.child);
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: palette.accentSecondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'AIによる講評',
                    style: TextStyle(fontWeight: FontWeight.bold, color: palette.textPrimary, fontSize: 18),
                  ),
                  if (_revealed) ...[
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: palette.textSecondary, size: 20),
                      tooltip: '講評を作り直す',
                      onPressed: loading ? null : () => registry.regenerateCommentary(widget.child),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (!_revealed)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(color: palette.accent),
                    ),
                    onPressed: () {
                      setState(() => _revealed = true);
                      registry.getOrGenerateCommentary(widget.child);
                    },
                    child: const Text('講評を見る'),
                  ),
                )
              else if (loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: palette.accent)),
                )
              else if (error != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      error,
                      style: TextStyle(fontSize: 12, color: palette.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                        side: BorderSide(color: palette.accent),
                      ),
                      onPressed: () => registry.getOrGenerateCommentary(widget.child),
                      child: const Text('再試行'),
                    ),
                  ],
                )
              else if (commentary != null) ...[
                _SpeakingCommentary(
                  summary: commentary.summary,
                  adviceList: commentary.adviceList,
                  timeLabel: _formatTime(commentary.generatedAt),
                  robotAsset: robotAssetForPercentage(commentary.dopagakiIndex.percentage),
                  palette: palette,
                ),
                if (commentary.scoreReason != null) ...[
                  const SizedBox(height: 12),
                  _ScoreReason(
                    percentage: commentary.dopagakiIndex.percentage,
                    label: commentary.dopagakiIndex.label,
                    reason: commentary.scoreReason!,
                    palette: palette,
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// マスコット「ロボまる」がAI講評を喋っているように見せる吹き出し表示。
class _SpeakingCommentary extends StatelessWidget {
  final String summary;
  final List<String> adviceList;
  final String timeLabel;
  final String robotAsset;
  final AppPalette palette;

  const _SpeakingCommentary({
    required this.summary,
    required this.adviceList,
    required this.timeLabel,
    required this.robotAsset,
    required this.palette,
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
                color: palette.accent.withValues(alpha: 0.15),
                border: Border.all(color: palette.accent, width: 1.5),
              ),
              child: SvgPicture.asset(robotAsset),
            ),
            const SizedBox(height: 4),
            Text(
              'ロボまる',
              style: TextStyle(fontSize: 10, color: palette.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.isDark ? Colors.white.withValues(alpha: 0.06) : palette.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: palette.isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : palette.cardBorder.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary, style: TextStyle(fontSize: 13, height: 1.5, color: palette.textPrimary)),
                const SizedBox(height: 12),
                ...adviceList.map(
                  (advice) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('・', style: TextStyle(color: palette.accent)),
                        Expanded(
                          child: Text(
                            advice,
                            style: TextStyle(fontSize: 12, color: palette.textSecondary),
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
                    style: TextStyle(fontSize: 10, color: palette.textDisabled),
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

/// ドパガキ指数の点数と、AIが挙げたその採点理由。
class _ScoreReason extends StatelessWidget {
  final int percentage;
  final String label;
  final String reason;
  final AppPalette palette;

  const _ScoreReason({
    required this.percentage,
    required this.label,
    required this.reason,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.isDark ? Colors.white.withValues(alpha: 0.06) : palette.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ドパガキ指数 $percentage%($label)の理由',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
