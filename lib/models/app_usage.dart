import 'package:flutter/material.dart';

/// 1つのアプリの利用時間。
class AppUsage {
  final String appName;
  final Duration duration;
  final Color color;

  /// SNS・動画・ゲームなど「ドバガキ指数」の対象になるアプリかどうか。
  final bool isDistracting;

  const AppUsage({
    required this.appName,
    required this.duration,
    required this.color,
    required this.isDistracting,
  });
}
