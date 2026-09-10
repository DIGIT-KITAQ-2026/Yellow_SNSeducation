import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/screen_time_day.dart';
import 'android_screen_time_service.dart';
import 'app_session.dart';
import 'screen_time_service.dart';
import 'supabase_screen_time_service.dart';

/// [ScreenTimeRegistry] が実際に使う複合実装。
///
/// UsageStats は「そのアプリが動いている端末自身」の利用時間しか読めないため、
/// 経路を2つに分ける:
///
/// - ログイン中の本人(子ども)が自分のスクリーンタイムを見る場合は、
///   この端末の [AndroidScreenTimeService] から直接取得し、表示のかたわら
///   Supabase(`screen_time_daily` / `screen_time_apps`)へ同期する。
/// - それ以外(保護者、または子ども以外の閲覧者)は Supabase から読む。
///
/// Android 以外のプラットフォーム(iOS・Web・デスクトップ)では、
/// どちらの経路でも [ScreenTimeUnavailableReason.unsupportedPlatform] を投げる。
/// これは保護者が Chrome 等でログインした場合も同様(意図的な仕様)。
class DeviceScreenTimeService implements ScreenTimeService {
  DeviceScreenTimeService({
    AndroidScreenTimeService? androidService,
    SupabaseScreenTimeService? supabaseService,
  })  : _android = androidService ?? AndroidScreenTimeService(),
        _supabase = supabaseService ?? const SupabaseScreenTimeService();

  final AndroidScreenTimeService _android;
  final SupabaseScreenTimeService _supabase;

  Future<bool> hasPermission() => _android.hasPermission();

  Future<void> openPermissionSettings() => _android.openPermissionSettings();

  @override
  Future<List<ScreenTimeDay>> fetchRecentScreenTime(
    String childId, {
    int days = 7,
  }) async {
    if (!AndroidScreenTimeService.isSupported) {
      throw const ScreenTimeUnavailableException(
        ScreenTimeUnavailableReason.unsupportedPlatform,
      );
    }

    if (_isOwnDevice(childId)) {
      final ownDeviceId = AppSession.instance.childProfile?.id;
      final result = await _android.fetchRecentScreenTime(childId, days: days);
      // 表示は端末データを優先する。Supabase への同期は失敗しても表示に
      // 影響させないため、待たずに投げっぱなしにしログのみ残す。
      if (ownDeviceId != null) {
        unawaited(_syncInBackground(ownDeviceId, result));
      }
      return result;
    }

    return _supabase.fetchRecentScreenTime(childId, days: days);
  }

  /// [childId](= [ScreenTimeRegistry._keyFor] のキー)が、今ログインしている
  /// 子ども本人のものかどうか。保護者ログイン時や、キーが別の子どものときは false。
  bool _isOwnDevice(String childId) {
    final session = AppSession.instance;
    if (!session.isChild) return false;
    final profile = session.childProfile;
    if (profile == null) return false;
    final ownKey = profile.id ?? '${profile.groupCode}/${profile.name}';
    return ownKey == childId;
  }

  Future<void> _syncInBackground(String childId, List<ScreenTimeDay> days) async {
    try {
      await _supabase.syncDays(childId, days);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('screen time sync to Supabase failed: $e');
      }
    }
  }
}
