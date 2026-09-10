/// 緯度経度の組。位置情報サービスと `ActivityService` の間で受け渡す最小の値。
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
