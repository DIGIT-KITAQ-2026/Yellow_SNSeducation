import '../models/geo_point.dart';

enum LocationUnavailableReason {
  serviceDisabled,
  denied,
  deniedForever,
  timeout,
  positionUnavailable,
  unsupported,
}

/// 取得できなかった理由を、そのまま画面に出せる日本語メッセージで運ぶ。
///
/// [detail] は開発者向けの原因情報(元例外のメッセージなど)で、画面には出さない。
/// ブラウザ/OSが返す生のエラー文字列を握りつぶさずログに残すために持たせている。
class LocationUnavailableException implements Exception {
  const LocationUnavailableException(this.reason, {this.detail});

  final LocationUnavailableReason reason;
  final String? detail;

  String get message => switch (reason) {
        LocationUnavailableReason.serviceDisabled =>
          '端末の位置情報がオフになっています。設定から有効にしてください',
        LocationUnavailableReason.denied =>
          '位置情報の利用が許可されませんでした。許可すると近くのアクティビティを探せます',
        LocationUnavailableReason.deniedForever =>
          '位置情報が「許可しない」に設定されています。端末の設定から変更してください',
        LocationUnavailableReason.timeout =>
          '現在地を取得できませんでした。もう一度お試しください',
        LocationUnavailableReason.positionUnavailable =>
          '現在地を特定できませんでした。時間をおいて、もう一度お試しください',
        LocationUnavailableReason.unsupported =>
          'この端末では現在地を取得できません',
      };

  @override
  String toString() => 'LocationUnavailableException($reason${detail != null ? ': $detail' : ''})';
}

/// 現在地の取得元を抽象化するインターフェース。[ScreenTimeService] と同じ理由で
/// 挟んでいる。実装は [GeolocatorLocationService] のみで、モックはテスト側が持つ
/// (`flutter test` はプラグインを持たないため、差し替えられないとテストが書けない)。
abstract class LocationService {
  Future<GeoPoint> currentPosition();
}
