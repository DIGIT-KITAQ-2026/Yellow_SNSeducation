import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yellow_sns_education/models/ai_commentary.dart';
import 'package:yellow_sns_education/models/app_usage.dart';
import 'package:yellow_sns_education/models/child_profile.dart';
import 'package:yellow_sns_education/models/dopagaki_index.dart';
import 'package:yellow_sns_education/models/screen_time_day.dart';
import 'package:yellow_sns_education/screens/home_body.dart';
import 'package:yellow_sns_education/services/ai_commentary_service.dart';
import 'package:yellow_sns_education/services/app_session.dart';
import 'package:yellow_sns_education/services/child_registry.dart';
import 'package:yellow_sns_education/services/screen_time_registry.dart';
import 'package:yellow_sns_education/services/screen_time_service.dart';

class _FakeScreenTimeService implements ScreenTimeService {
  @override
  Future<List<ScreenTimeDay>> fetchRecentScreenTime(String childId, {int days = 7}) async {
    return [
      ScreenTimeDay(
        date: DateTime(2026, 9, 6),
        usages: const [
          AppUsage(
            appName: 'YouTube',
            duration: Duration(minutes: 90),
            color: Colors.red,
            isDistracting: true,
          ),
          AppUsage(
            appName: '勉強アプリ',
            duration: Duration(minutes: 30),
            color: Colors.blue,
            isDistracting: false,
          ),
        ],
      ),
    ];
  }
}

class _FakeAiCommentaryService implements AiCommentaryService {
  @override
  Future<AiCommentary> generateCommentary({
    required ChildProfile child,
    required ScreenTimeDay screenTime,
    required DopagakiIndex dopagakiIndex,
  }) async {
    return AiCommentary(
      summary: 'テスト用の講評です。',
      adviceList: const ['テスト用のアドバイス'],
      generatedAt: DateTime(2026, 9, 7, 9, 0),
    );
  }
}

Widget buildApp() {
  return const MaterialApp(home: Scaffold(body: HomeBody()));
}

void main() {
  setUp(() {
    ChildRegistry.instance.clear();
    ScreenTimeRegistry.instance.clear();
    AppSession.instance.loginAsParent();
    ScreenTimeRegistry.instance.screenTimeService = _FakeScreenTimeService();
    ScreenTimeRegistry.instance.aiCommentaryService = _FakeAiCommentaryService();

    AppSession.instance.setGroupCode('group1');
    ChildRegistry.instance.addChild('テストこども1', groupCode: 'group1');
  });

  // FuturisticBackground runs a never-ending AnimationController, so
  // pumpAndSettle() would time out here; pump fixed durations instead.

  testWidgets('起動するとスクリーンタイムとAI講評が表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('昨日のドパガキ指数'), findsOneWidget);
    expect(find.text('先日のスクリーンタイム'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('AIによる講評'), 300);
    expect(find.text('AIによる講評'), findsOneWidget);
  });

  testWidgets('AI講評ボタンで講評が表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.scrollUntilVisible(find.text('講評を見る'), 300);
    await tester.tap(find.text('講評を見る'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('講評を見る'), findsNothing);
    expect(find.text('テスト用の講評です。'), findsOneWidget);
  });
}
