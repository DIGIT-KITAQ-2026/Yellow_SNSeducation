import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/geo_point.dart';
import 'location_service.dart';

/// 実機の位置情報APIを使う [LocationService] 実装。**web とモバイルで分岐する**:
/// web は `checkPermission()` が「ブラウザが Permissions API に対応していない」
/// だけで [LocationPermission.denied] を返す仕様があり、事前チェックで弾くと
/// 実際には取得できるのに失敗扱いになる。web はブラウザ自身が許可ダイアログを
/// 出すので、事前チェックを飛ばして直接 [Geolocator.getCurrentPosition] を呼び、
/// 投げられた例外を分類する(localhost / HTTPS は secure context なので Chrome
/// でそのまま動く)。
///
/// web では `getLastKnownPosition()` / `openAppSettings()` /
/// `openLocationSettings()` / `getServiceStatusStream()` が `UnsupportedError`
/// を投げる。`getLastKnownPosition()` はタイムアウト時のフォールバックとして
/// 使うが、web に入らないモバイル側の分岐からのみ呼ぶ。残りは一切使わない。
/// 測位を待つ上限。`getCurrentPosition` は「新しい位置の更新」を待つ実装なので、
/// 電源投入直後や屋内など測位に時間がかかる状況では15秒では足りないことがある。
/// 検索中はスピナーを出しているので、待たせてでも成功させるほうを優先する。
const _positionTimeout = Duration(seconds: 30);

/// タイムアウト時のフォールバックで許容する、キャッシュ位置の古さの上限。
/// 提案の精度は数百m〜数kmで足りるので少し古い測位でも実用上問題ないが、
/// 数日前の別の街の位置を使ってしまうと無関係な提案になるため上限を設ける。
const _lastKnownMaxAge = Duration(hours: 1);

class GeolocatorLocationService implements LocationService {
  @override
  Future<GeoPoint> currentPosition() async {
    try {
      if (kIsWeb) return await _getPosition();

      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationUnavailableException(LocationUnavailableReason.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationUnavailableException(LocationUnavailableReason.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        throw const LocationUnavailableException(LocationUnavailableReason.denied);
      }

      try {
        return await _getPosition();
      } on TimeoutException {
        // 測位が間に合わなかっただけなら、直前のキャッシュ位置で代替する。
        // getCurrentPosition は「新しい位置の更新」を待つ実装で、屋内や
        // エミュレータのように測位できない環境では毎回タイムアウトしてしまう。
        final cached = await _lastKnownPosition();
        if (cached != null) return cached;
        rethrow;
      }
    } on LocationUnavailableException catch (e) {
      _logFailure(e.reason, e.detail);
      rethrow;
    } on PermissionDeniedException catch (e) {
      // web はここに来る(事前チェックを飛ばしているため)。
      _logFailure(LocationUnavailableReason.denied, e.message);
      throw LocationUnavailableException(LocationUnavailableReason.denied, detail: e.message);
    } on LocationServiceDisabledException catch (e) {
      _logFailure(LocationUnavailableReason.serviceDisabled, e.toString());
      throw LocationUnavailableException(
        LocationUnavailableReason.serviceDisabled,
        detail: e.toString(),
      );
    } on TimeoutException catch (e) {
      _logFailure(LocationUnavailableReason.timeout, e.message);
      throw LocationUnavailableException(LocationUnavailableReason.timeout, detail: e.message);
    } on PositionUpdateException catch (e) {
      // 権限は許可されたが、ブラウザ/OSが実際の位置測位に失敗した場合
      // (web の POSITION_UNAVAILABLE など)。Chrome はこのとき e.message に
      // 具体的な原因(例: ネットワーク測位プロバイダのエラーコード)を入れてくる。
      _logFailure(LocationUnavailableReason.positionUnavailable, e.message);
      throw LocationUnavailableException(
        LocationUnavailableReason.positionUnavailable,
        detail: e.message,
      );
    } catch (e) {
      // 未対応プラットフォーム・プラグイン未登録など。
      _logFailure(LocationUnavailableReason.unsupported, e.toString());
      throw LocationUnavailableException(LocationUnavailableReason.unsupported, detail: e.toString());
    }
  }

  void _logFailure(LocationUnavailableReason reason, String? detail) {
    if (kDebugMode) {
      debugPrint('LocationService failed: $reason${detail != null ? ' / $detail' : ''}');
    }
  }

  /// 端末がキャッシュしている最後の測位結果。取れない・古すぎる場合は null。
  ///
  /// 失敗しても呼び出し元の TimeoutException を握り潰さないよう、ここで出た例外は
  /// ログに残すだけで投げ直さない(web では `UnsupportedError` になるため、
  /// そもそも web からは呼ばない)。
  Future<GeoPoint?> _lastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        // 端末に測位結果が1件も残っていない状態。位置情報を入れたばかりの実機や、
        // 現在地を設定していないエミュレータで起きる。
        _logFailure(LocationUnavailableReason.timeout, 'no last known position on device');
        return null;
      }
      final age = DateTime.now().difference(position.timestamp);
      if (age > _lastKnownMaxAge) {
        _logFailure(LocationUnavailableReason.timeout, 'last known position too old: $age');
        return null;
      }
      return GeoPoint(latitude: position.latitude, longitude: position.longitude);
    } catch (e) {
      _logFailure(LocationUnavailableReason.timeout, 'last known position failed: $e');
      return null;
    }
  }

  Future<GeoPoint> _getPosition() async {
    // desiredAccuracy は 14.x で削除される。LocationSettings は 13.x/14.x 共通。
    // 提案の精度には数百m〜数kmの誤差で十分なので medium にする
    // (Android は ACCESS_COARSE_LOCATION だけで取得でき、web は
    //  enableHighAccuracy=false 相当でWi-Fi/IP測位になる)。
    //
    // .timeout() を重ねて掛けているのは geolocator_web 4.1.4 の単位バグを
    // 迂回するため: html_geolocation_manager.dart が LocationSettings.timeLimit の
    // Duration を `.inMicroseconds` のままブラウザの PositionOptions.timeout
    // (ミリ秒を期待)に渡してしまい、30秒のつもりが約8.3時間になる。そのため
    // web ではブラウザ側のタイムアウトが実質無効で、ブラウザが応答しないまま
    // ハングし得る。LocationSettings.timeLimit はネイティブ側(Android/iOS)には
    // そのまま効くので、両方指定して二重に保険を掛けている。
    final position = await Geolocator.getCurrentPosition(
      locationSettings: _locationSettings(),
    ).timeout(_positionTimeout);
    return GeoPoint(latitude: position.latitude, longitude: position.longitude);
  }

  /// Android では素の [LocationSettings] ではなく [AndroidSettings] を渡す。
  /// `Geolocator.getCurrentPosition` は `locationSettings` が渡されると
  /// それをそのままプラットフォームへ送るため、素の [LocationSettings] だと
  /// Android 固有の設定(`forceLocationManager` / `timeInterval` など)が
  /// 一切適用されず、ネイティブ側の既定値で動いてしまう。
  LocationSettings _locationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: _positionTimeout,
        // Google Play開発者サービスがあれば FusedLocationProviderClient を使う。
        // 無い端末では geolocator が自動で LocationManager に切り替える。
        forceLocationManager: false,
        // 未指定だとネイティブ側の既定 5秒 が使われ、測位できていても最初の
        // コールバックが最大5秒遅れる。1回取れれば終わりなので短くしてよい。
        intervalDuration: const Duration(seconds: 1),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: _positionTimeout,
    );
  }
}
