import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_commentary.dart';
import '../models/child_profile.dart';
import '../models/dopagaki_index.dart';
import '../models/screen_time_day.dart';
import 'ai_commentary_service.dart';
import 'dopagaki_calculator.dart';

/// `ai-review` Edge Function(Gemini API呼び出し + `ai_reviews` への保存)を
/// 呼び出す実装。同じグループの親・子どちらから呼んでも、同じ
/// `(child_id, date)` に対しては Edge Function 側でキャッシュされた同一の
/// 講評が返る(=親子で同じ講評・同じドパガキ指数を見られる)。
///
/// 次のいずれかに該当する場合は [fallback](既定 [MockAiCommentaryService])
/// に委譲する:
/// - `child.id` が無い(Supabase未連携のローカル専用プロフィール)
/// - Edge Function が `gemini_not_configured` を返した(APIキー未設定)
/// - 通信エラー・レスポンスのパース失敗
class SupabaseAiCommentaryService implements AiCommentaryService {
  SupabaseAiCommentaryService({AiCommentaryService? fallback})
      : fallback = fallback ?? MockAiCommentaryService();

  final AiCommentaryService fallback;

  @override
  Future<AiCommentary> generateCommentary({
    required ChildProfile child,
    required ScreenTimeDay screenTime,
  }) async {
    final childId = child.id;
    if (childId == null) {
      return fallback.generateCommentary(child: child, screenTime: screenTime);
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'ai-review',
        body: {
          'child_id': childId,
          'date': _formatDate(screenTime.date),
          'screen_time': {
            'total_minutes': screenTime.total.inMinutes,
            'apps': [
              for (final usage in screenTime.usages)
                {
                  'name': usage.appName,
                  'minutes': usage.duration.inMinutes,
                  'is_distracting': usage.isDistracting,
                },
            ],
          },
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const FormatException('unexpected ai-review response shape');
      }
      if (data['error'] != null) {
        throw StateError('ai-review error: ${data['error']}');
      }

      final percentage = (data['dopagaki_score'] as num).round().clamp(0, 100);
      final summary = data['summary'] as String;
      final advice = (data['advice'] as List).map((e) => e.toString()).toList();
      final generatedAt = data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String) ?? DateTime.now()
          : DateTime.now();

      return AiCommentary(
        summary: summary,
        adviceList: advice,
        generatedAt: generatedAt,
        dopagakiIndex: DopagakiIndex(
          percentage: percentage,
          label: DopagakiCalculator.labelFor(percentage),
        ),
      );
    } catch (err, stack) {
      // APIキー未設定・通信エラー・想定外のレスポンス形状はすべてモックに
      // フォールバックする(ユーザー体験を止めないため)。
      debugPrint('SupabaseAiCommentaryService failed, falling back to mock: $err\n$stack');
      return fallback.generateCommentary(child: child, screenTime: screenTime);
    }
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
