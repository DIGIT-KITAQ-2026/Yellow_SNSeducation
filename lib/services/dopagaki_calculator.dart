import '../models/dopagaki_index.dart';
import '../models/screen_time_day.dart';

/// スクリーンタイムの記録から「ドバガキ指数」を計算する。
///
/// 指数 = その日の総利用時間に対する「ドバガキ対象アプリ
/// (SNS・動画・ゲームなど)」の利用時間の割合(%)。
class DopagakiCalculator {
  const DopagakiCalculator._();

  static DopagakiIndex calculate(ScreenTimeDay day) {
    final totalMinutes = day.total.inMinutes;
    if (totalMinutes <= 0) return DopagakiIndex.empty;

    final distractingMinutes = day.distractingTotal.inMinutes;
    final percentage =
        ((distractingMinutes / totalMinutes) * 100).round().clamp(0, 100);

    final String label;
    if (percentage < 30) {
      label = '良好';
    } else if (percentage < 60) {
      label = '注意';
    } else {
      label = '危険';
    }

    return DopagakiIndex(percentage: percentage, label: label);
  }
}
