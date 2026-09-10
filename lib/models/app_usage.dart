import 'package:flutter/material.dart';

/// 1つのアプリの利用時間。
class AppUsage {
  final String appName;
  final Duration duration;
  final Color color;

  /// Android のパッケージ名(`screen_time_apps.app_id` に対応)。
  /// モックデータや旧データには存在しないため null 許容。
  final String? appId;

  const AppUsage({
    required this.appName,
    required this.duration,
    required this.color,
    this.appId,
  });
}
