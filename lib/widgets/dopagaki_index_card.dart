import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/dopagaki_index.dart';
import '../theme/app_palette.dart';
import '../theme/theme_controller.dart';
import 'glass_card.dart';
import 'info_note_dialog.dart';
import 'robot_mascot.dart';

const _dopagakiIntro =
    'スマホの使い方と、勉強・遊び・休憩などの時間のバランスを見るための数字だよ!\n'
    'YouTubeやTikTokを見たり、ゲームをしたりする時間が多いと、'
    'ドパガキ指数が高くなるよ。';

const _dopagakiPoint = 'スマホをやめる必要はないよ!\n上手に使うことが大切だよ😊';

class _DopagakiLevel {
  final String emoji;
  final String range;
  final String label;
  final String detail;

  const _DopagakiLevel(this.emoji, this.range, this.label, this.detail);
}

const _dopagakiLevels = [
  _DopagakiLevel('🟢', '0〜24%', 'いい感じ!', 'スマホと上手につきあえているよ!'),
  _DopagakiLevel('🟡', '25〜49%', 'ちょっと注意!', '遊ぶ時間が少し多いかも?'),
  _DopagakiLevel('🟠', '50〜74%', '気をつけよう!', 'スマホの時間を少し減らしてみよう!'),
  _DopagakiLevel('🔴', '75〜100%', '使いすぎかも!', 'スマホ以外の遊びや勉強の時間も作ってみよう!'),
];

Future<void> _showDopagakiExplanation(BuildContext context, AppPalette palette) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: palette.dialogBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.cardBorder.withValues(alpha: palette.isDark ? 0.3 : 1)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(dialogContext).size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accent.withValues(alpha: 0.15),
                  border: Border.all(color: palette.accent, width: 1.5),
                ),
                child: SvgPicture.asset('assets/images/robot/robot_good.svg'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ドパガキ指数って?',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: palette.textPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              _dopagakiIntro,
              style: TextStyle(color: palette.textPrimary, height: 1.6, fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final level in _dopagakiLevels) ...[
                    if (level != _dopagakiLevels.first) const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${level.emoji} ${level.range}',
                          style: TextStyle(fontSize: 14, color: palette.textPrimary),
                        ),
                        const Spacer(),
                        Text(
                          level.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: palette.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level.detail,
                      style: TextStyle(fontSize: 12, color: palette.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.accent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 ポイント',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: palette.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dopagakiPoint,
                    style: TextStyle(color: palette.textPrimary, height: 1.5, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.accentOn,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('閉じる'),
            ),
          ],
        ),
        ),
        ),
      ),
    ),
  );
}

/// 「昨日のドパガキ指数」を表示するカード。
class DopagakiIndexCard extends StatelessWidget {
  final DopagakiIndex index;
  final bool isLoading;
  final bool isParent;

  const DopagakiIndexCard({
    super.key,
    required this.index,
    this.isLoading = false,
    this.isParent = false,
  });

  /// AI講評未生成・スクリーンタイム未取得の間は、`0%` と誤読されないよう
  /// パーセント表記の代わりに「—」を表示する。
  bool get _isUnscored => index.label == '未算出' || index.label == '記録なし';

  Color _colorFor(AppPalette palette) {
    switch (index.label) {
      case '危険':
        return palette.danger;
      case '注意':
        return palette.warning;
      case '良好':
        return palette.good;
      default:
        return palette.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final palette = ThemeController.instance.currentPalette;
        final color = _colorFor(palette);
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    isParent ? '昨日の依存指数' : '昨日のドパガキ指数',
                    style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  InfoButton(
                    onTap: () => _showDopagakiExplanation(context, palette),
                  ),
                  const Spacer(),
                  if (isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: palette.accent),
                    ),
                ],
              ),
              if (!isLoading) ...[
                const SizedBox(height: 12),
                // 指数の数値 → ロボット → ゲージ の縦並び。
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _isUnscored ? '—' : '${index.percentage}',
                      style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: color, height: 1),
                    ),
                    if (!_isUnscored)
                      Text(' %', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  index.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                ),
                if (!_isUnscored) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: SizedBox(
                      width: 132,
                      height: 132,
                      child: SvgPicture.asset(robotAssetForPercentage(index.percentage)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DopagakiGauge(percentage: index.percentage, palette: palette),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 危険(高い)〜安全(低い)のグラデーションゲージと、両端のロボットキャラクター。
class _DopagakiGauge extends StatelessWidget {
  final int percentage;
  final AppPalette palette;

  const _DopagakiGauge({required this.percentage, required this.palette});

  @override
  Widget build(BuildContext context) {
    final ratio = (percentage.clamp(0, 100)) / 100;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: SvgPicture.asset('assets/images/robot/robot_danger.svg'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  const markerSize = 14.0;
                  final markerLeft =
                      (constraints.maxWidth - markerSize) * (1 - ratio);
                  return SizedBox(
                    height: 22,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 12,
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(
                              colors: [palette.danger, palette.warning, palette.good],
                            ),
                          ),
                        ),
                        Positioned(
                          left: markerLeft,
                          child: Container(
                            width: markerSize,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.black45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('← 危険', style: TextStyle(fontSize: 9, color: palette.textSecondary)),
                  Text('安全 →', style: TextStyle(fontSize: 9, color: palette.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          height: 36,
          child: SvgPicture.asset('assets/images/robot/robot_good.svg'),
        ),
      ],
    );
  }
}
