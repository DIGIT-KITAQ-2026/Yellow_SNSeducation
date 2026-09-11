import 'package:flutter/material.dart';

import '../models/app_usage.dart';
import '../models/screen_time_day.dart';
import '../theme/app_palette.dart';

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '$h時間$m分';
  return '$m分';
}

/// 1日分のスクリーンタイムを、0〜23時の時間帯ごとの棒グラフで表示する。
/// [day] は最新日(先頭 = 昨日)を想定。[day.hourlyUsage] が未取得(null)の
/// 場合は「記録がありません」を表示する。
class HourlyScreenTimeChart extends StatelessWidget {
  final ScreenTimeDay day;
  final AppPalette palette;

  const HourlyScreenTimeChart({super.key, required this.day, required this.palette});

  /// 3時間おきにだけ時刻ラベルを出す(24本ぶんだと文字が詰まりすぎるため)。
  static const _labeledHours = {0, 3, 6, 9, 12, 15, 18, 21};

  @override
  Widget build(BuildContext context) {
    final hourly = day.hourlyUsage;
    if (hourly == null || hourly.length != 24) {
      return Text('時間帯別の記録がありません', style: TextStyle(color: palette.textSecondary));
    }

    final maxMinutes = hourly
        .map((d) => d.inMinutes)
        .fold<int>(1, (max, v) => v > max ? v : max);
    const chartHeight = 90.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '合計 ${_formatDuration(day.total)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: chartHeight + 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(24, (hour) {
              final minutes = hourly[hour].inMinutes;
              final ratio = maxMinutes == 0 ? 0.0 : minutes / maxMinutes;
              final barHeight = minutes == 0 ? 2.0 : (chartHeight * ratio).clamp(4.0, chartHeight);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: minutes == 0 ? palette.surfaceAlt : palette.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _labeledHours.contains(hour) ? '$hour' : '',
                        style: TextStyle(fontSize: 9, color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// 1日分のスクリーンタイムをアプリ別の横棒グラフで表示する。行をタップ
/// すると、そのアプリの「昨日 vs 先週平均」の詳細を見られる。
///
/// [weekDays] は新しい日付順(先頭が昨日)の直近7日分。先週平均の算出に
/// 使うため、表示対象の1日分だけでなく週全体を受け取る。
class AppBreakdownList extends StatelessWidget {
  final List<ScreenTimeDay> weekDays;
  final AppPalette palette;

  const AppBreakdownList({super.key, required this.weekDays, required this.palette});

  ScreenTimeDay get _day => weekDays.first;

  /// 週全体のうち、[appName] の合計時間(その日に使っていなければ0扱い)。
  Duration _weeklyAverageFor(String appName) {
    final total = weekDays.fold<Duration>(
      Duration.zero,
      (sum, d) => sum +
          d.usages
              .where((u) => u.appName == appName)
              .fold(Duration.zero, (s, u) => s + u.duration),
    );
    return Duration(minutes: (total.inMinutes / weekDays.length).round());
  }

  @override
  Widget build(BuildContext context) {
    final apps = _day.usagesByDuration;
    if (apps.isEmpty) {
      return Text('記録がありません', style: TextStyle(color: palette.textSecondary));
    }
    final maxMinutes = apps.first.duration.inMinutes;

    return Column(
      children: apps.map((app) {
        final ratio = maxMinutes == 0 ? 0.0 : app.duration.inMinutes / maxMinutes;
        return InkWell(
          onTap: () => _showAppDetail(context, app),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
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
                Icon(Icons.chevron_right_rounded, size: 16, color: palette.textDisabled),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showAppDetail(BuildContext context, AppUsage app) {
    final weeklyAverage = _weeklyAverageFor(app.appName);
    final deltaMinutes = app.duration.inMinutes - weeklyAverage.inMinutes;
    final barRatio = (app.duration.inMinutes == 0 && weeklyAverage.inMinutes == 0)
        ? 0.0
        : app.duration.inMinutes / [app.duration.inMinutes, weeklyAverage.inMinutes, 1].reduce((a, b) => a > b ? a : b);

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: palette.dialogBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: palette.cardBorder.withValues(alpha: palette.isDark ? 0.3 : 1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: app.color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(
                    app.appName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: palette.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DetailRow(label: '昨日', value: _formatDuration(app.duration), palette: palette, emphasize: true),
              const SizedBox(height: 10),
              _DetailRow(label: '先週平均', value: _formatDuration(weeklyAverage), palette: palette),
              const SizedBox(height: 10),
              Text(
                deltaMinutes == 0
                    ? '先週平均と同じ'
                    : '先週平均より ${deltaMinutes > 0 ? '+' : '-'}${_formatDuration(Duration(minutes: deltaMinutes.abs()))}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: deltaMinutes > 0 ? palette.warning : (deltaMinutes < 0 ? palette.good : palette.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(height: 10, color: palette.surfaceAlt),
                        Container(height: 10, width: constraints.maxWidth * barRatio, color: app.color),
                      ],
                    );
                  },
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
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final bool emphasize;

  const _DetailRow({required this.label, required this.value, required this.palette, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: palette.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 20 : 15,
            fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}
