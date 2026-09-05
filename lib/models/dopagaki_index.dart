/// 「ドバガキ指数」= その日の利用時間のうちSNS・動画・ゲームが占める割合(0〜100)。
class DopagakiIndex {
  final int percentage;
  final String label;

  const DopagakiIndex({required this.percentage, required this.label});

  static const empty = DopagakiIndex(percentage: 0, label: '記録なし');
}
