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
/// を投げるため、このクラスでは一切使わない。
const _positionTimeout = Duration(seconds: 15);

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

      return await _getPosition();
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

  Future<GeoPoint> _getPosition() async {
    // desiredAccuracy は 14.x で削除される。LocationSettings は 13.x/14.x 共通。
    // 提案の精度には数百m〜数kmの誤差で十分なので medium にする
    // (Android は ACCESS_COARSE_LOCATION だけで取得でき、web は
    //  enableHighAccuracy=false 相当でWi-Fi/IP測位になる)。
    //
    // .timeout() を重ねて掛けているのは geolocator_web 4.1.4 の単位バグを
    // 迂回するため: html_geolocation_manager.dart が LocationSettings.timeLimit の
    // Duration を `.inMicroseconds` のままブラウザの PositionOptions.timeout
    // (ミリ秒を期待)に渡してしまい、15秒のつもりが約4.17時間になる。そのため
    // web ではブラウザ側のタイムアウトが実質無効で、ブラウザが応答しないまま
    // ハングし得る。LocationSettings.timeLimit はネイティブ側(Android/iOS)には
    // そのまま効くので、両方指定して二重に保険を掛けている。
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: _positionTimeout,
      ),
    ).timeout(_positionTimeout);
    return GeoPoint(latitude: position.latitude, longitude: position.longitude);
  }
}
