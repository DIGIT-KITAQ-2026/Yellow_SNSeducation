import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yellow_sns_education/models/ai_commentary.dart';
import 'package:yellow_sns_education/models/app_usage.dart';
import 'package:yellow_sns_education/models/child_profile.dart';
import 'package:yellow_sns_education/models/dopagaki_index.dart';
import 'package:yellow_sns_education/models/geo_point.dart';
import 'package:yellow_sns_education/models/screen_time_day.dart';
import 'package:yellow_sns_education/screens/activity_body.dart';
import 'package:yellow_sns_education/screens/main_shell.dart';
import 'package:yellow_sns_education/services/activity_service.dart';
import 'package:yellow_sns_education/services/ai_commentary_service.dart';
import 'package:yellow_sns_education/services/app_session.dart';
import 'package:yellow_sns_education/services/child_registry.dart';
import 'package:yellow_sns_education/services/location_service.dart';
import 'package:yellow_sns_education/services/screen_time_registry.dart';
import 'package:yellow_sns_education/services/screen_time_service.dart';

// LocationService は main.dart 等での差し替えを行わない設計(lib/ にモックを
// 置かない)ため、テストはこの Fake を ActivityService.locationService に
// 直接代入する。
class _FakeLocationService implements LocationService {
  @override
  Future<GeoPoint> currentPosition() async =>
      const GeoPoint(latitude: 33.8834, longitude: 130.8751);
}

// MainShell を丸ごとpumpするテスト(タブ数の検証)は HomeBody も同時にbuildされる
// ため、ScreenTimeRegistry のデフォルトのモック実装に依存しないよう Fake を挟む。
class _FakeScreenTimeService implements ScreenTimeService {
  @override
  Future<List<ScreenTimeDay>> fetchRecentScreenTime(String childId, {int days = 7}) async {
    return [
      ScreenTimeDay(
        date: DateTime(2026, 9, 6),
        usages: const [
          AppUsage(
            appName: 'YouTube',
            duration: Duration(minutes: 30),
            color: Colors.red,
            isDistracting: true,
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
      adviceList: const [],
      generatedAt: DateTime(2026, 9, 7, 9, 0),
      dopagakiIndex: const DopagakiIndex(percentage: 0, label: '良好'),
    );
  }
}

Widget buildActivityBodyApp() {
  return const MaterialApp(home: Scaffold(body: ActivityBody()));
}

void main() {
  setUp(() {
    ChildRegistry.instance.clear();
    ScreenTimeRegistry.instance.clear();
    ScreenTimeRegistry.instance.screenTimeService = _FakeScreenTimeService();
    ScreenTimeRegistry.instance.aiCommentaryService = _FakeAiCommentaryService();
    ActivityService.locationService = _FakeLocationService();
    AppSession.instance.setGroupCode('group1');
  });

  // FuturisticBackground runs a never-ending AnimationController, so
  // pumpAndSettle() would time out here; pump fixed durations instead.

  testWidgets('子でログイン時、説明カードと「現在地から探す」ボタンが表示される', (tester) async {
    final child = ChildRegistry.instance.addChild('テストこども1', groupCode: 'group1', id: 'child-1');
    AppSession.instance.loginAsChild(child);

    await tester.pumpWidget(buildActivityBodyApp());
    await tester.pump();

    expect(find.text('SNSの時間のかわりに、近くで無料で楽しめることを探そう'), findsOneWidget);
    expect(find.text('現在地から探す'), findsOneWidget);
    // initState では自動検索しない(ログインしただけで位置情報ダイアログ/
    // Gemini課金が走らないことの確認)。
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('子どもは4タブ(おでかけを含む)、親は3タブ(おでかけが無い)', (tester) async {
    final child = ChildRegistry.instance.addChild('テストこども1', groupCode: 'group1', id: 'child-1');

    AppSession.instance.loginAsChild(child);
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('おでかけ'), findsOneWidget);

    AppSession.instance.loginAsParent();
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('おでかけ'), findsNothing);
  });
}
