/// AIによるスクリーンタイムの講評結果。
class AiCommentary {
  final String summary;
  final List<String> adviceList;
  final DateTime generatedAt;

  const AiCommentary({
    required this.summary,
    required this.adviceList,
    required this.generatedAt,
  });
}
