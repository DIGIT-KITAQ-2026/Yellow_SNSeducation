import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yellow_sns_education/models/app_usage.dart';
import 'package:yellow_sns_education/models/screen_time_day.dart';
import 'package:yellow_sns_education/theme/app_palette.dart';
import 'package:yellow_sns_education/theme/theme_controller.dart';
import 'package:yellow_sns_education/widgets/screen_time_charts.dart';

Widget buildApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

AppPalette get _palette => ThemeController.instance.currentPalette;

void main() {
  testWidgets('時間帯別データがあれば合計時間と棒グラフを表示する', (tester) async {
    final hourly = List<Duration>.generate(
      24,
      (h) => h == 20 ? const Duration(minutes: 45) : Duration.zero,
    );
    final day = ScreenTimeDay(
      date: DateTime(2026, 9, 10),
      usages: const [
        AppUsage(appName: 'YouTube', duration: Duration(minutes: 45), color: Colors.red),
      ],
      hourlyUsage: hourly,
    );

    await tester.pumpWidget(buildApp(HourlyScreenTimeChart(day: day, palette: _palette)));

    expect(find.textContaining('合計'), findsOneWidget);
    expect(find.textContaining('45分'), findsOneWidget);
    expect(find.text('時間帯別の記録がありません'), findsNothing);
  });

  testWidgets('時間帯別データが無ければ記録なしメッセージを表示する', (tester) async {
    final day = ScreenTimeDay(
      date: DateTime(2026, 9, 10),
      usages: const [],
      hourlyUsage: null,
    );

    await tester.pumpWidget(buildApp(HourlyScreenTimeChart(day: day, palette: _palette)));

    expect(find.text('時間帯別の記録がありません'), findsOneWidget);
  });
}
