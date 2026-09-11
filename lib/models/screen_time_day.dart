import 'app_usage.dart';

/// ある1日分のスクリーンタイム記録(アプリ別内訳込み)。
class ScreenTimeDay {
  final DateTime date;
  final List<AppUsage> usages;

  /// 0時始まりの24要素で、各時間帯(0〜23時)の全アプリ合計利用時間。
  /// 取得できていない(未対応端末・イベントログ切れ・旧データ等)場合は null。
  final List<Duration>? hourlyUsage;

  const ScreenTimeDay({required this.date, required this.usages, this.hourlyUsage});

  Duration get total =>
      usages.fold(Duration.zero, (sum, u) => sum + u.duration);

  /// 利用時間が長い順に並べたアプリ一覧。
  List<AppUsage> get usagesByDuration =>
      [...usages]..sort((a, b) => b.duration.compareTo(a.duration));
}
