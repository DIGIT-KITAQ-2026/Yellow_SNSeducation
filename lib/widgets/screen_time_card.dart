import 'package:flutter/material.dart';

import '../models/screen_time_day.dart';
import '../theme/theme_controller.dart';
import 'glass_card.dart';
import 'screen_time_charts.dart';

/// 「先日のスクリーンタイム」カード。直近7日間の推移とアプリ別の内訳を表示する。
class ScreenTimeCard extends StatelessWidget {
  final List<ScreenTimeDay>? days;
  final bool isLoading;

  const ScreenTimeCard({super.key, required this.days, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final palette = ThemeController.instance.currentPalette;
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '先日のスクリーンタイム',
                style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary),
              ),
              const SizedBox(height: 12),
              if (isLoading || days == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: palette.accent)),
                )
              else ...[
                WeeklyScreenTimeChart(days: days!, palette: palette),
                const SizedBox(height: 8),
                Divider(color: palette.cardBorder.withValues(alpha: palette.isDark ? 0.3 : 0.6)),
                const SizedBox(height: 8),
                Text(
                  'アプリ別の内訳(昨日)',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
                const SizedBox(height: 8),
                AppBreakdownList(weekDays: days!, palette: palette),
              ],
            ],
          ),
        );
      },
    );
  }
}
