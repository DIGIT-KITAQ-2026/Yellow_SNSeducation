/// 「ドパガキ指数」= SNS・動画・ゲームなどへの依存・没入の深刻さをAIが0〜100で採点したもの。
class DopagakiIndex {
  final int percentage;
  final String label;

  const DopagakiIndex({required this.percentage, required this.label});

  /// スクリーンタイムの記録自体が無い場合。
  static const empty = DopagakiIndex(percentage: 0, label: '記録なし');

  /// AI講評をまだ生成していない場合(記録はあるが未算出)。
  static const notGenerated = DopagakiIndex(percentage: 0, label: '未算出');
}
