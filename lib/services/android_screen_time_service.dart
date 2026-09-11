import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_usage.dart';
import '../models/screen_time_day.dart';
import 'app_catalog.dart';
import 'screen_time_service.dart';

/// Android の `UsageStatsManager` を MethodChannel 経由で呼び出す実装。
///
/// 「使用状況へのアクセス」は特別なアクセス権であり、ユーザーが端末の設定画面
/// (`Settings.ACTION_USAGE_ACCESS_SETTINGS`)を自分で開いて許可する必要がある。
/// 未許可の状態で呼ぶと [ScreenTimeUnavailableReason.permissionRequired] を、
/// Android 以外のプラットフォームでは [ScreenTimeUnavailableReason.unsupportedPlatform]
/// を投げる。
class AndroidScreenTimeService implements ScreenTimeService {
  AndroidScreenTimeService();

  static const MethodChannel _channel =
      MethodChannel('com.yellow.yellow_sns_education/screen_time');

  /// この端末でスクリーンタイム取得を試みてよいプラットフォームかどうか。
  /// Web は `dart:io` の `Platform` が使えないため `kIsWeb` を先に見る
  /// (`geolocator_location_service.dart` と同じ流儀)。
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      _logFailure(e);
      return false;
    } on MissingPluginException catch (e) {
      _logFailure(e);
      return false;
    }
  }

  Future<void> openPermissionSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('openSettings');
    } on PlatformException catch (e) {
      _logFailure(e);
    } on MissingPluginException catch (e) {
      _logFailure(e);
    }
  }

  @override
  Future<List<ScreenTimeDay>> fetchRecentScreenTime(
    String childId, {
    int days = 7,
  }) async {
    if (!isSupported) {
      throw const ScreenTimeUnavailableException(
        ScreenTimeUnavailableReason.unsupportedPlatform,
      );
    }
    if (!await hasPermission()) {
      throw const ScreenTimeUnavailableException(
        ScreenTimeUnavailableReason.permissionRequired,
      );
    }

    late final List<Object?> raw;
    try {
      // 「今日」を含めて取得し、後で先頭(今日)を捨てて「昨日が先頭」の
      // 契約(ScreenTimeService.fetchRecentScreenTime のドキュメント参照)に揃える。
      final result = await _channel.invokeMethod<List<Object?>>(
        'queryDailyUsage',
        {'days': days + 1},
      );
      if (result == null) {
        throw const ScreenTimeUnavailableException(
          ScreenTimeUnavailableReason.failed,
          detail: 'queryDailyUsage returned null',
        );
      }
      raw = result;
    } on PlatformException catch (e) {
      throw ScreenTimeUnavailableException(
        ScreenTimeUnavailableReason.failed,
        detail: e.toString(),
      );
    } on MissingPluginException catch (e) {
      throw ScreenTimeUnavailableException(
        ScreenTimeUnavailableReason.unsupportedPlatform,
        detail: e.toString(),
      );
    }

    final parsedDays = raw.map(_parseDay).toList();
    // ネイティブ側は新しい日付順(今日が先頭)で返すので、今日を除いて返す。
    final result = parsedDays.length > days
        ? parsedDays.sublist(1)
        : parsedDays;

    if (result.isEmpty) return result;

    // 時間帯別グラフは最新日(先頭 = 昨日)分だけ使うため、その1日分だけ
    // 追加で取得する。失敗しても日別データの表示は壊さず、hourlyUsage は
    // null のまま返す。
    final hourly = await _fetchHourlyUsage(result.first.date);
    if (hourly == null) return result;

    final withHourly = ScreenTimeDay(
      date: result.first.date,
      usages: result.first.usages,
      hourlyUsage: hourly,
    );
    return [withHourly, ...result.sublist(1)];
  }

  Future<List<Duration>?> _fetchHourlyUsage(DateTime date) async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'queryHourlyUsage',
        {'date': _formatDate(date)},
      );
      if (result == null) return null;
      return result
          .map((minutes) => Duration(minutes: (minutes as num).toInt()))
          .toList();
    } on PlatformException catch (e) {
      _logFailure(e);
      return null;
    } on MissingPluginException catch (e) {
      _logFailure(e);
      return null;
    }
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  ScreenTimeDay _parseDay(Object? entry) {
    final map = Map<Object?, Object?>.from(entry as Map);
    final date = DateTime.parse(map['date'] as String);
    final appsRaw = (map['apps'] as List<Object?>? ?? const []);
    final usages = appsRaw.map((appEntry) {
      final appMap = Map<Object?, Object?>.from(appEntry as Map);
      final packageName = appMap['packageName'] as String;
      final label = appMap['label'] as String? ?? packageName;
      final minutes = (appMap['minutes'] as num).toInt();
      return AppUsage(
        appName: label,
        duration: Duration(minutes: minutes),
        color: AppCatalog.colorFor(packageName),
        appId: packageName,
      );
    }).toList();

    return ScreenTimeDay(date: date, usages: usages);
  }

  void _logFailure(Object e) {
    if (kDebugMode) {
      debugPrint('AndroidScreenTimeService failed: $e');
    }
  }
}
