import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/dopagaki_index.dart';
import '../theme/app_palette.dart';
import '../theme/theme_controller.dart';
import 'glass_card.dart';
import 'robot_mascot.dart';

/// 「昨日のドパガキ指数」を表示するカード。
class DopagakiIndexCard extends StatelessWidget {
  final DopagakiIndex index;
  final bool isLoading;

  const DopagakiIndexCard({super.key, required this.index, this.isLoading = false});

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '昨日のドパガキ指数',
                          style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary),
                        ),
                        if (!isLoading) ...[
                          const SizedBox(height: 4),
                          Text(index.label, style: TextStyle(fontSize: 12, color: color)),
                        ],
                      ],
                    ),
                  ),
                  if (isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: palette.accent),
                    )
                  else ...[
                    if (!_isUnscored) ...[
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: SvgPicture.asset(robotAssetForPercentage(index.percentage)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: color, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isUnscored
                          ? Text(
                              '—',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${index.percentage}',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                                ),
                                Text(' %', style: TextStyle(fontSize: 13, color: color)),
                              ],
                            ),
                    ),
                  ],
                ],
              ),
              if (!isLoading && !_isUnscored) ...[
                const SizedBox(height: 16),
                _DopagakiGauge(percentage: index.percentage, palette: palette),
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
          width: 52,
          height: 52,
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
          width: 52,
          height: 52,
          child: SvgPicture.asset('assets/images/robot/robot_good.svg'),
        ),
      ],
    );
  }
}
