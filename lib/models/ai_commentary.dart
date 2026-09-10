import 'dopagaki_index.dart';

/// AIによるスクリーンタイムの講評結果。
class AiCommentary {
  final String summary;
  final List<String> adviceList;
  final DateTime generatedAt;

  /// この講評とセットでAIが算出したドパガキ指数。
  final DopagakiIndex dopagakiIndex;

  /// ドパガキ指数をその点数にした理由。`score_reason` 列の追加より前に生成された
  /// 既存の講評には無いため null 許容。
  final String? scoreReason;

  const AiCommentary({
    required this.summary,
    required this.adviceList,
    required this.generatedAt,
    required this.dopagakiIndex,
    this.scoreReason,
  });
}
