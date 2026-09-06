import 'package:flutter/material.dart';

import '../models/dopagaki_index.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

/// 「昨日のドパガキ指数」を表示するカード。
class DopagakiIndexCard extends StatelessWidget {
  final DopagakiIndex index;
  final bool isLoading;

  const DopagakiIndexCard({super.key, required this.index, this.isLoading = false});

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
      child: Row(
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
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _color, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
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
      ),
    );
  }
}
