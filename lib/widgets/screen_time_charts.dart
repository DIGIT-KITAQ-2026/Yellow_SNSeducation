import 'package:flutter/material.dart';

import '../models/screen_time_day.dart';
import '../theme/app_palette.dart';

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '$h時間$m分';
  return '$m分';
}

/// 直近7日間の合計スクリーンタイムを棒グラフで表示する。
/// [days] は新しい日付順(先頭が昨日)を想定。
class WeeklyScreenTimeChart extends StatelessWidget {
  final List<ScreenTimeDay> days;
  final AppPalette palette;

  const WeeklyScreenTimeChart({super.key, required this.days, required this.palette});

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Text('記録がありません', style: TextStyle(color: palette.textSecondary));
    }

    final chronological = days.reversed.toList();
    final maxMinutes = chronological
        .map((d) => d.total.inMinutes)
        .fold<int>(1, (max, v) => v > max ? v : max);
    const chartHeight = 110.0;

    return SizedBox(
      height: chartHeight + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: chronological.map((day) {
          final ratio = maxMinutes == 0 ? 0.0 : day.total.inMinutes / maxMinutes;
          final barHeight = (chartHeight * ratio).clamp(4.0, chartHeight);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatDuration(day.total),
                    style: TextStyle(fontSize: 9, color: palette.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _weekdayLabels[day.date.weekday - 1],
                    style: TextStyle(fontSize: 11, color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 1日分のスクリーンタイムをアプリ別の横棒グラフで表示する。
class AppBreakdownList extends StatelessWidget {
  final ScreenTimeDay day;
  final AppPalette palette;

  const AppBreakdownList({super.key, required this.day, required this.palette});

  @override
  Widget build(BuildContext context) {
    final apps = day.usagesByDuration;
    if (apps.isEmpty) {
      return Text('記録がありません', style: TextStyle(color: palette.textSecondary));
    }
    final maxMinutes = apps.first.duration.inMinutes;

    return Column(
      children: apps.map((app) {
        final ratio = maxMinutes == 0 ? 0.0 : app.duration.inMinutes / maxMinutes;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                child: Text(
                  app.appName,
                  style: TextStyle(fontSize: 12, color: palette.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(height: 10, color: palette.surfaceAlt),
                          Container(
                            height: 10,
                            width: constraints.maxWidth * ratio,
                            color: app.color,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: Text(
                  _formatDuration(app.duration),
                  style: TextStyle(fontSize: 11, color: palette.textSecondary),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
