import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_commentary.dart';
import '../models/child_profile.dart';
import '../models/dopagaki_index.dart';
import '../models/screen_time_day.dart';
import 'ai_commentary_service.dart';
import 'dopagaki_calculator.dart';

enum AiCommentaryFailure { notConfigured, failed }

/// `ai-review` Edge Function が失敗を返したときの、画面にそのまま出せる
/// 日本語メッセージ付き例外。`activity-suggest` の [ActivitySuggestException]
/// と同じ形。
///
/// [detail] は開発者向けの原因情報で、画面には出さない。
class AiCommentaryException implements Exception {
  const AiCommentaryException(this.failure, {this.detail});

  /// `FunctionException.details` から失敗理由を判定する。
  factory AiCommentaryException.fromFunctionException(FunctionException e) {
    final details = e.details;
    final error = details is Map ? details['error'] : null;
    return AiCommentaryException(_failureFromErrorCode(error), detail: e.toString());
  }

  /// 200応答の body に載る `error` 値からの変換(`gemini_not_configured` はこの経路)。
  factory AiCommentaryException.fromErrorCode(Object? error) {
    return AiCommentaryException(_failureFromErrorCode(error), detail: '$error');
  }

  static AiCommentaryFailure _failureFromErrorCode(Object? error) => switch (error) {
        'gemini_not_configured' => AiCommentaryFailure.notConfigured,
        _ => AiCommentaryFailure.failed,
      };

  final AiCommentaryFailure failure;
  final String? detail;

  String get message => switch (failure) {
        AiCommentaryFailure.notConfigured =>
          '現在AIの講評は利用できません。おうちの方にお知らせください',
        AiCommentaryFailure.failed =>
          '講評を取得できませんでした。しばらくしてから、もう一度お試しください',
      };

  @override
  String toString() => 'AiCommentaryException($failure${detail != null ? ': $detail' : ''})';
}

/// `ai-review` Edge Function(Gemini API呼び出し + `ai_reviews` への保存)を
/// 呼び出す実装。同じグループの親・子どちらから呼んでも、同じ
/// `(child_id, date)` に対しては Edge Function 側でキャッシュされた同一の
/// 講評が返る(=親子で同じ講評・同じドパガキ指数を見られる)。
///
/// 常に実際のGemini呼び出しの結果を採用する(モックへのフォールバックは行わない)。
/// 失敗した場合は [AiCommentaryException](または想定外のレスポンス形状であれば
/// [FormatException])を投げる。呼び出し側([ScreenTimeRegistry.getOrGenerateCommentary])
/// が捕捉して画面に伝える。
class SupabaseAiCommentaryService implements AiCommentaryService {
  const SupabaseAiCommentaryService();

  @override
  Future<AiCommentary> generateCommentary({
    required ChildProfile child,
    required ScreenTimeDay screenTime,
  }) async {
    final childId = child.id;
    if (childId == null) {
      // Supabase未連携のローカル専用プロフィール(id無し)。本番のログイン
      // フローでは常に id が入るため、通常は起こらない。
      throw const AiCommentaryException(
        AiCommentaryFailure.failed,
        detail: 'child.id is null (local-only profile, not linked to Supabase)',
      );
    }

    final FunctionResponse response;
    try {
      response = await Supabase.instance.client.functions.invoke(
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
    } on FunctionException catch (e) {
      throw AiCommentaryException.fromFunctionException(e);
    }

    final data = response.data;
    if (data is! Map) {
      throw const FormatException('unexpected ai-review response shape');
    }
    if (data['error'] != null) {
      throw AiCommentaryException.fromErrorCode(data['error']);
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
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
