import 'dart:math';

import 'package:flutter/material.dart';

import '../models/app_usage.dart';
import '../models/screen_time_day.dart';

/// スクリーンタイムの取得元を抽象化するインターフェース。
///
/// 現在は [MockScreenTimeService] のみを利用しているが、
/// 実機のOS API(Android UsageStats / iOS Screen Time)や
/// バックエンドAPIと連携する際は、このインターフェースを実装したクラスに
/// 差し替えるだけで済むようにしている。
abstract class ScreenTimeService {
  /// 直近[days]日分のスクリーンタイムを、新しい日付順(昨日が先頭)で返す。
  Future<List<ScreenTimeDay>> fetchRecentScreenTime(
    String childId, {
    int days = 7,
  });
}

class _AppTemplate {
  final String name;
  final Color color;
  final bool isDistracting;
  final int minMinutes;
  final int maxMinutes;

  const _AppTemplate(
    this.name,
    this.color,
    this.isDistracting,
    this.minMinutes,
    this.maxMinutes,
  );
}

/// 開発・デモ用のモック実装。子どもIDごとに固定シードの乱数を使うため、
/// アプリを再起動しても同じ子どもなら同じような傾向のデータが再現される。
class MockScreenTimeService implements ScreenTimeService {
  static const _catalog = [
    _AppTemplate('YouTube', Color(0xFFFF5C5C), true, 15, 110),
    _AppTemplate('TikTok', Color(0xFFEF4D8C), true, 10, 90),
    _AppTemplate('Instagram', Color(0xFFB06AF2), true, 5, 60),
    _AppTemplate('ゲームアプリ', Color(0xFFF5A524), true, 10, 80),
    _AppTemplate('LINE', Color(0xFF4ADE80), false, 5, 40),
    _AppTemplate('勉強アプリ', Color(0xFF60A5FA), false, 0, 45),
  ];

  @override
  Future<List<ScreenTimeDay>> fetchRecentScreenTime(
    String childId, {
    int days = 7,
  }) async {
    // 実際のAPI呼び出しの遅延を模したダミーウェイト。
    await Future.delayed(const Duration(milliseconds: 400));

    final random = Random(childId.hashCode);
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    return List.generate(days, (i) {
      final date = startOfToday.subtract(Duration(days: i + 1));
      final usages = <AppUsage>[];
      for (final template in _catalog) {
        final range = template.maxMinutes - template.minMinutes;
        final minutes = template.minMinutes +
            (range <= 0 ? 0 : random.nextInt(range + 1));
        if (minutes <= 0) continue;
        usages.add(
          AppUsage(
            appName: template.name,
            duration: Duration(minutes: minutes),
            color: template.color,
            isDistracting: template.isDistracting,
          ),
        );
      }
      return ScreenTimeDay(date: date, usages: usages);
    });
  }
}
