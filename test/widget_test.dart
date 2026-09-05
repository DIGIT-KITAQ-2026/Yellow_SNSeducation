import 'package:flutter_test/flutter_test.dart';

import 'package:yellow_sns_education/main.dart';

void main() {
  testWidgets('起動するとスクリーンタイムとAI講評が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const YellowApp());
    await tester.pumpAndSettle();

    expect(find.text('昨日のドバガキ指数'), findsOneWidget);
    expect(find.text('先日のスクリーンタイム'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('AIによる講評'), 300);
    expect(find.text('AIによる講評'), findsOneWidget);
  });

  testWidgets('AI講評ボタンで講評が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const YellowApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('講評を見る'), 300);
    await tester.tap(find.text('講評を見る'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('講評を見る'), findsNothing);
  });
}
