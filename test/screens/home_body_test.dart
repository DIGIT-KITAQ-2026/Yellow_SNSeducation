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
          ),
          AppUsage(
            appName: '勉強アプリ',
            duration: Duration(minutes: 30),
            color: Colors.blue,
          ),
        ],
      ),
    ];
  }
}

class _FakeAiCommentaryService implements AiCommentaryService {
  int callCount = 0;
  int fetchCount = 0;

  /// `fetchCommentary`(保存済みの講評の読み取り)が返す値。null なら「まだ
  /// 生成されていない」を表す。
  AiCommentary? saved;

  @override
  Future<AiCommentary> generateCommentary({
    required ChildProfile child,
    required ScreenTimeDay screenTime,
    bool force = false,
  }) async {
    callCount++;
    return AiCommentary(
      summary: callCount == 1 ? 'テスト用の講評です。' : '作り直した講評です。',
      adviceList: const ['テスト用のアドバイス'],
      generatedAt: DateTime(2026, 9, 7, 9, 0),
      scoreReason: 'YouTube 90分がドパガキ対象で、総利用時間120分の大半を占めるためです。',
      dopagakiIndex: const DopagakiIndex(percentage: 75, label: '危険'),
    );
  }

  @override
  Future<AiCommentary?> fetchCommentary({
    required ChildProfile child,
    required DateTime date,
  }) async {
    fetchCount++;
    return saved;
  }
}

Widget buildApp() {
  return const MaterialApp(home: Scaffold(body: HomeBody()));
}

// ignore: library_private_types_in_public_api
late _FakeAiCommentaryService aiService;

/// 子ども本人としてログインし直す。講評の**生成**が走るのはこの状態のときだけ
/// (`ScreenTimeRegistry.canGenerateCommentary`)。
void loginAsChild() {
  final child = ChildRegistry.instance.children.first;
  AppSession.instance.loginAsChild(child);
}

void main() {
  setUp(() {
    ChildRegistry.instance.clear();
    ScreenTimeRegistry.instance.clear();
    AppSession.instance.loginAsParent();
    aiService = _FakeAiCommentaryService();
    ScreenTimeRegistry.instance.screenTimeService = _FakeScreenTimeService();
    ScreenTimeRegistry.instance.aiCommentaryService = aiService;

    AppSession.instance.setGroupCode('group1');
    ChildRegistry.instance.addChild('テストこども1', groupCode: 'group1');
    loginAsChild();
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

  testWidgets('講評にはドパガキ指数の採点理由が表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.scrollUntilVisible(find.text('講評を見る'), 300);
    await tester.tap(find.text('講評を見る'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ドパガキ指数 75%(危険)の理由'), findsOneWidget);
    expect(
      find.text('YouTube 90分がドパガキ対象で、総利用時間120分の大半を占めるためです。'),
      findsOneWidget,
    );
  });

  testWidgets('リロードボタンを押すと講評が作り直される', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.scrollUntilVisible(find.text('講評を見る'), 300);
    await tester.tap(find.text('講評を見る'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('テスト用の講評です。'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();

    // 古い講評は押した瞬間に消え、ローディング表示に切り替わる。
    expect(find.text('テスト用の講評です。'), findsNothing);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('作り直した講評です。'), findsOneWidget);
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

  group('保護者ログイン時', () {
    setUp(() {
      // 保護者は自分の端末に子どものスクリーンタイムを持たないため、講評を
      // 生成させない(= 空データで ai_reviews を上書きさせない)。
      AppSession.instance.loginAsParent();
      AppSession.instance.setGroupCode('group1');
      ChildRegistry.instance.selectChild('テストこども1');
    });

    testWidgets('保存済みの講評を読むだけで、生成は呼ばれない', (tester) async {
      aiService.saved = AiCommentary(
        summary: '保存済みの講評です。',
        adviceList: const ['保存済みのアドバイス'],
        generatedAt: DateTime(2026, 9, 7, 9, 0),
        scoreReason: '保存済みの採点理由です。',
        dopagakiIndex: const DopagakiIndex(percentage: 40, label: '注意'),
      );

      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.scrollUntilVisible(find.text('講評を見る'), 300);
      await tester.tap(find.text('講評を見る'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('保存済みの講評です。'), findsOneWidget);
      expect(aiService.callCount, 0);
      expect(aiService.fetchCount, greaterThan(0));
    });

    testWidgets('子どもがまだ講評を作っていなければ案内を出し、生成はしない', (tester) async {
      aiService.saved = null;

      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.scrollUntilVisible(find.text('講評を見る'), 300);
      await tester.tap(find.text('講評を見る'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('昨日の講評はまだありません。お子さまがアプリを開くと作成されます'),
        findsOneWidget,
      );
      expect(find.text('読み込み直す'), findsOneWidget);
      expect(aiService.callCount, 0);
    });

    testWidgets('引っ張って更新しても講評を作り直さない', (tester) async {
      aiService.saved = null;

      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final child = ChildRegistry.instance.children.first;
      await ScreenTimeRegistry.instance.refreshScreenTime(child);
      await ScreenTimeRegistry.instance.getOrGenerateCommentary(child);

      expect(aiService.callCount, 0);
    });
  });
}
