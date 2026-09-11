import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 毎朝8時に送る「先日のスクリーンタイムを確認しましょう」通知の文面を組み立てる。
///
/// プラグインに一切触れない純粋関数なので、プラットフォーム抜きでテストできる。
/// 保護者かつ同じグループに子どもが1人もいない場合は、知らせる相手がいないので
/// null を返す(通知を出さない)。
({String title, String body})? dailyScreenTimeNotificationContent({
  required bool isChild,
  required List<String> childNames,
}) {
  if (isChild) {
    return (title: '先日のスクリーンタイム', body: '先日のスクリーンタイムを確認しましょう。');
  }
  if (childNames.isEmpty) return null;
  final names = childNames.join('、');
  return (title: '$namesのスクリーンタイム', body: '$namesの先日のスクリーンタイムを確認してみましょう。');
}

/// 毎朝8時のスクリーンタイム確認通知を、端末ローカルの
/// [flutter_local_notifications] でスケジュールするシングルトン。
///
/// [ScreenTimeRegistry] や [ChildRegistry] と同じ「ClassName._() +
/// static final instance」の流儀に合わせている。スクリーンタイム機能自体が
/// Android専用のため、この通知もAndroid専用とし、他プラットフォームでは
/// すべてのメソッドが何もせずに返る。
class DailyNotificationService {
  DailyNotificationService._();

  static final DailyNotificationService instance = DailyNotificationService._();

  static const _channelId = 'daily_screen_time';
  static const _channelName = 'スクリーンタイム通知';
  static const _channelDescription = '毎朝、前日のスクリーンタイムを確認するお知らせです。';

  /// 毎朝の定期通知に使う固定ID。テスト送信([showNow])はこれと衝突しない別IDを使う。
  static const _scheduledNotificationId = 1;
  static const _testNotificationId = 2;

  /// 申請・承認などの都度通知([showMessage])に使うID。上2つと衝突させないため
  /// 10から始め、連続して届いても上書きし合わないよう発行のたびに進める。
  static const _messageNotificationIdBase = 10;
  static const _messageNotificationIdCount = 10;
  int _messageNotificationOffset = 0;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  /// `main()` から一度だけ呼ぶ。タイムゾーンデータの読み込みとプラグインの初期化のみ行い、
  /// スケジュールは [syncForSession] に任せる。
  Future<void> init() async {
    if (!_supported || _initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  /// ログイン(またはプロフィール変更)のたびに呼ぶ。既存のスケジュールを一度消し、
  /// 現在のロール・子ども一覧に基づいた毎朝8時の通知を登録し直す。
  ///
  /// 失敗してもログイン処理自体は止めたくないので、全体を try/catch で囲み、
  /// 通知が出せなくてもエラーを外に伝播させない。
  Future<void> syncForSession({required bool isChild, required List<String> childNames}) async {
    if (!_supported) return;
    try {
      await init();
      await cancelAll();

      final content = dailyScreenTimeNotificationContent(isChild: isChild, childNames: childNames);
      if (content == null) return;

      final granted = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      if (granted == false) return;

      await _plugin.zonedSchedule(
        _scheduledNotificationId,
        content.title,
        content.body,
        _next8am(),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('DailyNotificationService.syncForSession failed: $e');
    }
  }

  /// ログアウト時に呼ぶ。次にログインする(別の)ユーザー向けの文面が
  /// 端末に残り続けないようにする。
  Future<void> cancelAll() async {
    if (!_supported) return;
    try {
      await _plugin.cancel(_scheduledNotificationId);
    } catch (e) {
      debugPrint('DailyNotificationService.cancelAll failed: $e');
    }
  }

  /// 動作確認用。8時を待たずに、いま計算できる文面で通知を即時発火する。
  /// アカウント情報画面の「通知テスト送信」ボタンから呼ばれる。
  Future<void> showNow({required bool isChild, required List<String> childNames}) async {
    if (!_supported) return;
    try {
      await init();
      final content = dailyScreenTimeNotificationContent(isChild: isChild, childNames: childNames);
      if (content == null) return;

      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      await _plugin.show(
        _testNotificationId,
        content.title,
        content.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
          ),
        ),
      );
    } catch (e) {
      debugPrint('DailyNotificationService.showNow failed: $e');
    }
  }

  /// 任意の文面で即時通知を出す。申請・承認・スクリーンタイム更新を
  /// [NotificationRealtime] が受け取ったときに呼ばれる。
  ///
  /// FCM を入れていないので、これが届くのはアプリが起動している間だけ。
  /// 出せなくてもアプリ内のお知らせベルには載るため、失敗は握りつぶす。
  Future<void> showMessage({required String title, required String body}) async {
    if (!_supported) return;
    try {
      await init();

      // 直前の通知を上書きしないよう、IDを一定の範囲で使い回す。
      final id = _messageNotificationIdBase +
          (_messageNotificationOffset++ % _messageNotificationIdCount);

      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
          ),
        ),
      );
    } catch (e) {
      debugPrint('DailyNotificationService.showMessage failed: $e');
    }
  }

  /// 次に来る午前8:00(すでに今日の8時を過ぎていれば翌日の8時)を、
  /// 日本時間の [tz.TZDateTime] として返す。
  tz.TZDateTime _next8am() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
