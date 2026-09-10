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
  }) async {
    return AiCommentary(
      summary: 'テスト用の講評です。',
      adviceList: const ['テスト用のアドバイス'],
      generatedAt: DateTime(2026, 9, 7, 9, 0),
      dopagakiIndex: const DopagakiIndex(percentage: 75, label: '危険'),
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

  testWidgets('AI講評は「講評を見る」を押すまで表示されない', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // データ自体はホーム画面表示時に裏側で取得済みだが、本文はボタンを
    // 押すまで隠されている。
    await tester.scrollUntilVisible(find.text('講評を見る'), 300);
    expect(find.text('テスト用の講評です。'), findsNothing);

    await tester.tap(find.text('講評を見る'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('講評を見る'), findsNothing);
    expect(find.text('テスト用の講評です。'), findsOneWidget);
  });

  testWidgets('ドパガキ指数は起動時に自動でAIの値になる', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // ホーム画面の表示だけで(「講評を見る」を押さなくても)
    // _FakeAiCommentaryService が返す「危険」になる。
    expect(find.text('未算出'), findsNothing);
    expect(find.text('危険'), findsOneWidget);
  });
}
