import 'package:flutter/material.dart';

import '../models/dopagaki_index.dart';
import '../theme/app_theme.dart';

/// 「昨日のドバガキ指数」を表示するカード。
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
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '昨日のドバガキ指数',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                  border: Border.all(color: _color),
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
      ),
    );
  }
}
