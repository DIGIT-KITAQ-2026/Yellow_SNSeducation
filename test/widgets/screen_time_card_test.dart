import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yellow_sns_education/widgets/screen_time_card.dart';

Widget buildApp(ScreenTimeCard card) {
  return MaterialApp(home: Scaffold(body: card));
}

void main() {
  testWidgets('取得失敗時はエラーメッセージと再試行ボタンを表示する', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      buildApp(
        ScreenTimeCard(
          days: null,
          error: 'スクリーンタイムを取得できませんでした。もう一度お試しください',
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('スクリーンタイムを取得できませんでした。もう一度お試しください'), findsOneWidget);
    expect(find.text('再試行'), findsOneWidget);
    expect(find.text('設定を開く'), findsNothing);

    await tester.tap(find.text('再試行'));
    expect(retried, isTrue);
  });

  testWidgets('権限未許可時は設定を開くボタンを表示する', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      buildApp(
        ScreenTimeCard(
          days: null,
          error: '使用状況へのアクセスを許可すると、スクリーンタイムを表示できます',
          needsPermission: true,
          onOpenSettings: () => opened = true,
        ),
      ),
    );

    expect(find.text('設定を開く'), findsOneWidget);
    expect(find.text('再試行'), findsNothing);

    await tester.tap(find.text('設定を開く'));
    expect(opened, isTrue);
  });

  testWidgets('未対応端末はメッセージのみでボタンを出さない', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const ScreenTimeCard(
          days: null,
          error: 'お使いの端末ではスクリーンタイム参照ができません',
        ),
      ),
    );

    expect(find.text('お使いの端末ではスクリーンタイム参照ができません'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
