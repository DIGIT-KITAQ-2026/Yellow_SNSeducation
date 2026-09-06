import 'package:flutter/material.dart';

import '../models/screen_time_day.dart';
import 'glass_card.dart';
import 'screen_time_charts.dart';

/// 「先日のスクリーンタイム」カード。直近7日間の推移とアプリ別の内訳を表示する。
class ScreenTimeCard extends StatelessWidget {
  final List<ScreenTimeDay>? days;
  final bool isLoading;

  const ScreenTimeCard({super.key, required this.days, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '先日のスクリーンタイム',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 12),
          if (isLoading || days == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            WeeklyScreenTimeChart(days: days!),
            const SizedBox(height: 8),
            Divider(color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 8),
            Text(
              'アプリ別の内訳(昨日)',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 8),
            AppBreakdownList(day: days!.first),
          ],
        ],
      ),
    );
  }
}
