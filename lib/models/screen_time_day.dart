import 'app_usage.dart';

/// ある1日分のスクリーンタイム記録(アプリ別内訳込み)。
class ScreenTimeDay {
  final DateTime date;
  final List<AppUsage> usages;

  const ScreenTimeDay({required this.date, required this.usages});

  Duration get total =>
      usages.fold(Duration.zero, (sum, u) => sum + u.duration);

  Duration get distractingTotal => usages
      .where((u) => u.isDistracting)
      .fold(Duration.zero, (sum, u) => sum + u.duration);

  /// 利用時間が長い順に並べたアプリ一覧。
  List<AppUsage> get usagesByDuration =>
      [...usages]..sort((a, b) => b.duration.compareTo(a.duration));
}
