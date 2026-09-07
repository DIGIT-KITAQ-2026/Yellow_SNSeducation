import 'dopagaki_index.dart';

/// AIによるスクリーンタイムの講評結果。
class AiCommentary {
  final String summary;
  final List<String> adviceList;
  final DateTime generatedAt;

  /// この講評とセットでAIが算出したドパガキ指数。
  final DopagakiIndex dopagakiIndex;

  const AiCommentary({
    required this.summary,
    required this.adviceList,
    required this.generatedAt,
    required this.dopagakiIndex,
  });
}
