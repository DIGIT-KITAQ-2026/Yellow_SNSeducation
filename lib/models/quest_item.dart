class QuestItem {
  const QuestItem({
    required this.title,
    required this.points,
    this.detail = '',
  });

  final String title;
  final String points;
  final String detail;
}
