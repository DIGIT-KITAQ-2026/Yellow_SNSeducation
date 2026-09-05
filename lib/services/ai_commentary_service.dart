import '../models/ai_commentary.dart';
import '../models/child_profile.dart';
import '../models/dopagaki_index.dart';
import '../models/screen_time_day.dart';

/// 「AIによる講評」を生成するインターフェース。
///
/// バックエンドのAI講評API(担当・使用モデルは未定)が用意でき次第、
/// このインターフェースを実装したクラス(例: `BackendAiCommentaryService`)を
/// 作成して [MockAiCommentaryService] と差し替えればよい。
/// 呼び出し側([AppState.getOrGenerateCommentary])はこのインターフェースにしか
/// 依存していないため、差し替えによる影響範囲はこのファイルのみで収まる。
abstract class AiCommentaryService {
  Future<AiCommentary> generateCommentary({
    required ChildProfile child,
    required ScreenTimeDay screenTime,
    required DopagakiIndex dopagakiIndex,
  });
}

/// バックエンド未接続の間、開発・デモに使うルールベースのモック実装。
class MockAiCommentaryService implements AiCommentaryService {
  @override
  Future<AiCommentary> generateCommentary({
    required ChildProfile child,
    required ScreenTimeDay screenTime,
    required DopagakiIndex dopagakiIndex,
  }) async {
    // 実際のAI API呼び出しの遅延を模したダミーウェイト。
    await Future.delayed(const Duration(milliseconds: 800));

    final topApps = screenTime.usagesByDuration.take(2).toList();
    final topAppText = topApps.isEmpty
        ? 'アプリの利用'
        : topApps.map((a) => a.appName).join('と');

    final String summary;
    switch (dopagakiIndex.label) {
      case '危険':
        summary =
            '${child.name}さんは昨日、利用時間の${dopagakiIndex.percentage}%を$topAppTextなどに使っており、'
            'ドバガキ指数は「危険」水準です。まとまった時間、他の活動に切り替えられていない可能性があります。';
        break;
      case '注意':
        summary =
            '${child.name}さんは昨日、$topAppTextの利用がやや多く、'
            'ドバガキ指数は「注意」水準(${dopagakiIndex.percentage}%)でした。習慣化する前に一声かけると良さそうです。';
        break;
      case '記録なし':
        summary = '${child.name}さんの昨日のスクリーンタイム記録がありません。端末の連携状況を確認してください。';
        break;
      default:
        summary =
            '${child.name}さんは昨日、勉強・連絡系アプリの利用バランスが取れており、'
            'ドバガキ指数は「良好」水準(${dopagakiIndex.percentage}%)でした。この調子を維持できるとよいですね。';
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
    );
  }
}
