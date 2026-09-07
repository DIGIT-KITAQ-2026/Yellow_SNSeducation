import '../models/dopagaki_index.dart';
import '../models/screen_time_day.dart';

/// スクリーンタイムの記録から「ドパガキ指数」を計算する。
///
/// 本来の算出はAI([AiCommentaryService])が行うが、AI未接続時のモック
/// (`MockAiCommentaryService`)のフォールバック用に、単純な比率ベースの
/// 計算をここに残している。
///
/// 指数 = その日の総利用時間に対する「ドパガキ対象アプリ
/// (SNS・動画・ゲームなど)」の利用時間の割合(%)。
class DopagakiCalculator {
  const DopagakiCalculator._();

  /// 0〜100のスコアから、危険度ラベルを決める。AIが返したスコアの
  /// ラベル付けにも使う。
  static String labelFor(int percentage) {
    if (percentage < 30) return '良好';
    if (percentage < 60) return '注意';
    return '危険';
  }

  static DopagakiIndex calculate(ScreenTimeDay day) {
    final totalMinutes = day.total.inMinutes;
    if (totalMinutes <= 0) return DopagakiIndex.empty;

    final distractingMinutes = day.distractingTotal.inMinutes;
    final percentage =
        ((distractingMinutes / totalMinutes) * 100).round().clamp(0, 100);

    return DopagakiIndex(percentage: percentage, label: labelFor(percentage));
  }
}
