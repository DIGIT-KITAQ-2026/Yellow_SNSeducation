import '../models/ai_commentary.dart';
import '../models/child_profile.dart';
import '../models/screen_time_day.dart';

/// 「AIによる講評」(要約・アドバイス・ドパガキ指数)を生成するインターフェース。
///
/// ドパガキ指数もこのサービスが算出する(単純な比率ではなく、AIがスクリーン
/// タイムの内訳から総合的に採点する)。
/// 呼び出し側([ScreenTimeRegistry.getOrGenerateCommentary])はこのインターフェースにしか
/// 依存していないため、実装の差し替えによる影響範囲はこのファイルのみで収まる。
abstract class AiCommentaryService {
  /// [force] が true なら、サーバ側に同じ日付の講評が保存済みでも作り直す。
  /// 引っ張って更新でスクリーンタイムを取り直したときに、古いデータで作られた
  /// 講評が残り続けないようにするため。
  Future<AiCommentary> generateCommentary({
    required ChildProfile child,
    required ScreenTimeDay screenTime,
    bool force = false,
  });
}
