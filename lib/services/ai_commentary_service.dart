import '../models/ai_commentary.dart';
import '../models/child_profile.dart';
import '../models/screen_time_day.dart';
import 'dopagaki_calculator.dart';

/// 「AIによる講評」(要約・アドバイス・ドパガキ指数)を生成するインターフェース。
///
/// ドパガキ指数もこのサービスが算出する(単純な比率ではなく、AIがスクリーン
/// タイムの内訳から総合的に採点する)。
/// 呼び出し側([ScreenTimeRegistry.getOrGenerateCommentary])はこのインターフェースにしか
/// 依存していないため、実装の差し替えによる影響範囲はこのファイルのみで収まる。
abstract class AiCommentaryService {
  Future<AiCommentary> generateCommentary({
    required ChildProfile child,
    required ScreenTimeDay screenTime,
  });
}

/// AI API呼び出しが行えない場合(APIキー未設定・通信エラーなど)に使う、
/// ルールベースのフォールバック実装。[SupabaseAiCommentaryService] が内部で
/// フォールバック先として使うほか、開発・テスト時の既定実装としても使う。
class MockAiCommentaryService implements AiCommentaryService {
  @override
  Future<AiCommentary> generateCommentary({
    required ChildProfile child,
    required ScreenTimeDay screenTime,
  }) async {
    // 実際のAI API呼び出しの遅延を模したダミーウェイト。
    await Future.delayed(const Duration(milliseconds: 800));

    final dopagakiIndex = DopagakiCalculator.calculate(screenTime);

    final topApps = screenTime.usagesByDuration.take(2).toList();
    final topAppText = topApps.isEmpty
        ? 'アプリの利用'
        : topApps.map((a) => a.appName).join('と');

    final String summary;
    switch (dopagakiIndex.label) {
      case '危険':
        summary =
            '${child.name}さんは昨日、利用時間の${dopagakiIndex.percentage}%を$topAppTextなどに使っており、'
            'ドパガキ指数は「危険」水準です。まとまった時間、他の活動に切り替えられていない可能性があります。';
        break;
      case '注意':
        summary =
            '${child.name}さんは昨日、$topAppTextの利用がやや多く、'
            'ドパガキ指数は「注意」水準(${dopagakiIndex.percentage}%)でした。習慣化する前に一声かけると良さそうです。';
        break;
      case '記録なし':
        summary = '${child.name}さんの昨日のスクリーンタイム記録がありません。端末の連携状況を確認してください。';
        break;
      default:
        summary =
            '${child.name}さんは昨日、勉強・連絡系アプリの利用バランスが取れており、'
            'ドパガキ指数は「良好」水準(${dopagakiIndex.percentage}%)でした。この調子を維持できるとよいですね。';
    }

    final advice = <String>[];
    if (dopagakiIndex.percentage >= 60) {
      advice.add('就寝1時間前は$topAppTextの利用を控えるルールを提案してみましょう。');
      advice.add('クエストや報酬を活用して、他の活動へのモチベーションを作るのもおすすめです。');
    } else if (dopagakiIndex.percentage >= 30) {
      advice.add('利用時間帯が偏っていないか、今週のスクリーンタイム推移も合わせて確認してみましょう。');
    } else {
      advice.add('良いバランスが続いています。引き続き様子を見守りましょう。');
    }

    return AiCommentary(
      summary: summary,
      adviceList: advice,
      generatedAt: DateTime.now(),
      dopagakiIndex: dopagakiIndex,
    );
  }
}
