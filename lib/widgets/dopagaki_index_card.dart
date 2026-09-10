import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/dopagaki_index.dart';
import '../theme/app_colors.dart';
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

  Color get _color {
    switch (index.label) {
      case '危険':
        return AppColors.danger;
      case '注意':
        return AppColors.warning;
      case '良好':
        return AppColors.good;
      default:
        return Colors.white.withValues(alpha: 0.6);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const Text(
                      '昨日のドパガキ指数',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    if (!isLoading) ...[
                      const SizedBox(height: 4),
                      Text(index.label, style: TextStyle(fontSize: 12, color: _color)),
                    ],
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
                    border: Border.all(color: _color, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isUnscored
                      ? Text(
                          '—',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _color),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${index.percentage}',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _color),
                            ),
                            Text(' %', style: TextStyle(fontSize: 13, color: _color)),
                          ],
                        ),
                ),
              ],
            ],
          ),
          if (!isLoading && !_isUnscored) ...[
            const SizedBox(height: 16),
            _DopagakiGauge(percentage: index.percentage),
          ],
        ],
      ),
    );
  }
}

/// 危険(高い)〜安全(低い)のグラデーションゲージと、両端のロボットキャラクター。
class _DopagakiGauge extends StatelessWidget {
  final int percentage;

  const _DopagakiGauge({required this.percentage});

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
                            gradient: const LinearGradient(
                              colors: [AppColors.danger, AppColors.warning, AppColors.good],
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
                  Text('← 危険', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.6))),
                  Text('安全 →', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.6))),
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
