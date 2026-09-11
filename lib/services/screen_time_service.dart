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

enum ScreenTimeUnavailableReason {
  /// この端末(プラットフォーム)ではスクリーンタイムを取得できない(Web/iOS等)。
  unsupportedPlatform,

  /// 「使用状況へのアクセス」がまだ許可されていない(Androidのみ)。
  permissionRequired,

  /// 取得を試みたが失敗した(通信エラー・OS側のエラーなど)。
  failed,
}

/// スクリーンタイムを取得できなかった理由を、そのまま画面に出せる
/// 日本語メッセージで運ぶ。[LocationUnavailableException] と同じ形。
///
/// [detail] は開発者向けの原因情報(元例外のメッセージなど)で、画面には出さない。
class ScreenTimeUnavailableException implements Exception {
  const ScreenTimeUnavailableException(this.reason, {this.detail});

  final ScreenTimeUnavailableReason reason;
  final String? detail;

  String get message => switch (reason) {
        ScreenTimeUnavailableReason.unsupportedPlatform =>
          'お使いの端末ではスクリーンタイム参照ができません',
        ScreenTimeUnavailableReason.permissionRequired =>
          '使用状況へのアクセスを許可すると、スクリーンタイムを表示できます',
        ScreenTimeUnavailableReason.failed =>
          'スクリーンタイムを取得できませんでした。もう一度お試しください',
      };

  @override
  String toString() =>
      'ScreenTimeUnavailableException($reason${detail != null ? ': $detail' : ''})';
}

class _AppTemplate {
  final String name;
  final Color color;
  final int minMinutes;
  final int maxMinutes;

  const _AppTemplate(this.name, this.color, this.minMinutes, this.maxMinutes);
}

/// 開発・デモ用のモック実装。子どもIDごとに固定シードの乱数を使うため、
/// アプリを再起動しても同じ子どもなら同じような傾向のデータが再現される。
class MockScreenTimeService implements ScreenTimeService {
  static const _catalog = [
    _AppTemplate('YouTube', Color(0xFFFF5C5C), 15, 110),
    _AppTemplate('TikTok', Color(0xFFEF4D8C), 10, 90),
    _AppTemplate('Instagram', Color(0xFFB06AF2), 5, 60),
    _AppTemplate('ゲームアプリ', Color(0xFFF5A524), 10, 80),
    _AppTemplate('LINE', Color(0xFF4ADE80), 5, 40),
    _AppTemplate('勉強アプリ', Color(0xFF60A5FA), 0, 45),
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
          ),
        );
      }
      // 時間帯別グラフのデモ用に、最新日(i == 0、先頭 = 昨日)だけ生成する。
      // 夕方〜夜に寄せた重みで、その日の合計利用時間(usages)に按分する。
      final hourlyUsage = i == 0 ? _generateHourlyUsage(random, usages) : null;
      return ScreenTimeDay(date: date, usages: usages, hourlyUsage: hourlyUsage);
    });
  }

  /// 学校・就寝時間帯を薄く、夕方〜夜を厚くした重みで [totalMinutes] を
  /// 24時間に按分する(実機でよく見る分布に寄せたデモ用の乱数)。
  static const _hourWeights = [
    1, 1, 1, 1, 1, 1, // 0-5時: 就寝
    2, 3, 2, 2, 2, 2, // 6-11時: 登校・学校
    3, 2, 2, 2, 3, 5, // 12-17時: 昼休み・下校
    8, 9, 8, 6, 4, 2, // 18-23時: 夕食後〜就寝前
  ];

  List<Duration> _generateHourlyUsage(Random random, List<AppUsage> usages) {
    final totalMinutes =
        usages.fold<int>(0, (sum, u) => sum + u.duration.inMinutes);
    if (totalMinutes <= 0) {
      return List.generate(24, (_) => Duration.zero);
    }

    // 重みに軽くランダム性を持たせつつ、各時間は端末上の実利用と同じ上限
    // (60分)でクランプする。
    final jittered = _hourWeights
        .map((w) => (w * (0.7 + random.nextDouble() * 0.6)))
        .toList();
    final weightSum = jittered.fold<double>(0, (s, w) => s + w);

    var remaining = totalMinutes;
    final minutesByHour = List<int>.filled(24, 0);
    for (var hour = 0; hour < 24; hour++) {
      final share = hour == 23
          ? remaining
          : (totalMinutes * jittered[hour] / weightSum).round();
      final minutes = share.clamp(0, 60).clamp(0, remaining);
      minutesByHour[hour] = minutes;
      remaining -= minutes;
    }
    return minutesByHour.map((m) => Duration(minutes: m)).toList();
  }
}
