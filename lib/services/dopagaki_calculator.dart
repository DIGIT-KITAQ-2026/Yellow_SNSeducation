/// ドパガキ指数のラベル付け(危険度の3段階)。
///
/// 指数の算出自体はAI([AiCommentaryService])が行う。ここには、AIが返した
/// スコアからラベル文字列を決めるための、単純なしきい値判定だけを置く。
class DopagakiCalculator {
  const DopagakiCalculator._();

  /// 0〜100のスコアから、危険度ラベルを決める。
  static String labelFor(int percentage) {
    if (percentage < 30) return '良好';
    if (percentage < 60) return '注意';
    return '危険';
  }
}
