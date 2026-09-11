/// ドパガキ指数(0〜100)を25%刻みの4段階に分け、対応するロボット画像を返す。
///
/// 0-24%: 緑(良好) / 25-49%: 黄(注意) / 50-74%: オレンジ(警戒) / 75-100%: 赤(危険)
String robotAssetForPercentage(int percentage) {
  final p = percentage.clamp(0, 100);
  if (p < 25) return 'assets/images/robot/robot_good.svg';
  if (p < 50) return 'assets/images/robot/robot_warning.svg';
  if (p < 75) return 'assets/images/robot/robot_neutral.svg';
  return 'assets/images/robot/robot_danger.svg';
}
