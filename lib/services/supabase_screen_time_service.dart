import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_usage.dart';
import '../models/screen_time_day.dart';
import 'app_catalog.dart';
import 'screen_time_service.dart';

/// `screen_time_daily` / `screen_time_apps` を読み書きする実装。
///
/// 子ども端末で `AndroidScreenTimeService` から取得したデータを [syncDays] で
/// 書き込み、保護者(または子ども以外の閲覧者)は [fetchRecentScreenTime] で
/// そのデータを読む。Thin wrapper over the Supabase client, [QuestService] /
/// [GiftService] と同じ形。
class SupabaseScreenTimeService implements ScreenTimeService {
  const SupabaseScreenTimeService();

  static SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<ScreenTimeDay>> fetchRecentScreenTime(
    String childId, {
    int days = 7,
  }) async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final rangeStart = startOfToday.subtract(Duration(days: days));

    // total_minutes は usages から都度計算するため(ScreenTimeDay.total)、
    // ここでは screen_time_apps の内訳だけを読めば足りる。
    final List<Object?> appRows;
    try {
      appRows = await _client
          .from('screen_time_apps')
          .select('date, app_id, app_label, minutes')
          .eq('child_id', childId)
          .gte('date', _formatDate(rangeStart))
          .lt('date', _formatDate(startOfToday));
    } on PostgrestException catch (e) {
      throw ScreenTimeUnavailableException(
        ScreenTimeUnavailableReason.failed,
        detail: e.toString(),
      );
    }

    final appsByDate = <String, List<AppUsage>>{};
    for (final row in appRows) {
      final map = row as Map<String, dynamic>;
      final date = map['date'] as String;
      final appId = map['app_id'] as String;
      final label = map['app_label'] as String;
      final minutes = (map['minutes'] as num).toInt();
      appsByDate.putIfAbsent(date, () => []).add(
            AppUsage(
              appName: label,
              duration: Duration(minutes: minutes),
              color: AppCatalog.colorFor(appId),
              appId: appId,
            ),
          );
    }

    // 時間帯別グラフは最新日(先頭 = 昨日)分だけ使うため、その1日分だけ読む。
    final yesterday = startOfToday.subtract(const Duration(days: 1));
    final hourlyByDate = await _fetchHourlyUsage(childId, yesterday);

    // 新しい日付順(昨日が先頭)で、データが無い日も空リストで埋めて日付軸を保つ。
    return List.generate(days, (i) {
      final date = startOfToday.subtract(Duration(days: i + 1));
      final key = _formatDate(date);
      return ScreenTimeDay(
        date: date,
        usages: appsByDate[key] ?? const [],
        hourlyUsage: key == _formatDate(yesterday) ? hourlyByDate : null,
      );
    });
  }

  /// [date]分の時間帯別内訳(0〜23時、24要素)。行が1件も無ければ null。
  Future<List<Duration>?> _fetchHourlyUsage(String childId, DateTime date) async {
    final List<Object?> rows;
    try {
      rows = await _client
          .from('screen_time_hourly')
          .select('hour, minutes')
          .eq('child_id', childId)
          .eq('date', _formatDate(date));
    } on PostgrestException catch (e) {
      throw ScreenTimeUnavailableException(
        ScreenTimeUnavailableReason.failed,
        detail: e.toString(),
      );
    }
    if (rows.isEmpty) return null;

    final minutesByHour = List<int>.filled(24, 0);
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final hour = (map['hour'] as num).toInt();
      if (hour < 0 || hour > 23) continue;
      minutesByHour[hour] = (map['minutes'] as num).toInt();
    }
    return minutesByHour.map((m) => Duration(minutes: m)).toList();
  }

  /// 子ども端末で取得したその日までの分を upsert する。
  /// 呼び出し元([DeviceScreenTimeService])は成功を待たずに投げっぱなしにしてよい
  /// (表示は端末データを優先し、同期失敗はログのみに留める設計のため)。
  Future<void> syncDays(String childId, List<ScreenTimeDay> days) async {
    for (final day in days) {
      final dateStr = _formatDate(day.date);
      await _client.from('screen_time_daily').upsert(
        {
          'child_id': childId,
          'date': dateStr,
          'total_minutes': day.total.inMinutes,
        },
        onConflict: 'child_id,date',
      );

      // その日にもう使われていないアプリの行を消してから入れ直す。
      await _client
          .from('screen_time_apps')
          .delete()
          .eq('child_id', childId)
          .eq('date', dateStr);

      final appsWithId = day.usages.where((u) => u.appId != null).toList();
      if (appsWithId.isNotEmpty) {
        await _client.from('screen_time_apps').upsert([
          for (final usage in appsWithId)
            {
              'child_id': childId,
              'date': dateStr,
              'app_id': usage.appId,
              'app_label': usage.appName,
              'minutes': usage.duration.inMinutes,
            },
        ], onConflict: 'child_id,date,app_id');
      }

      final hourly = day.hourlyUsage;
      if (hourly != null) {
        // アプリ別内訳と同じ流儀: その日の行を消してから、0分でない時間帯だけ入れ直す。
        await _client
            .from('screen_time_hourly')
            .delete()
            .eq('child_id', childId)
            .eq('date', dateStr);

        final nonZero = [
          for (var hour = 0; hour < hourly.length; hour++)
            if (hourly[hour].inMinutes > 0) (hour, hourly[hour].inMinutes),
        ];
        if (nonZero.isNotEmpty) {
          await _client.from('screen_time_hourly').upsert([
            for (final (hour, minutes) in nonZero)
              {
                'child_id': childId,
                'date': dateStr,
                'hour': hour,
                'minutes': minutes,
              },
          ], onConflict: 'child_id,date,hour');
        }
      }
    }

    await _client.rpc('purge_old_screen_time');
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
