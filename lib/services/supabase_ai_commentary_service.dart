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
/// 生成([generateCommentary])を呼ぶのは子ども本人の端末だけで、保護者は
/// [fetchCommentary] で `ai_reviews` を直接読むだけにする(`ai_reviews_select`
/// のRLSにより、同じグループのメンバーなら select できる)。保護者側は端末の
/// スクリーンタイムを持たず、Supabaseから読んだ「まだ同期されていない=空」の
/// データで生成してしまうと、その日の講評が記録なし・0点で固定されてしまうため。
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
    bool force = false,
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
          'force': force,
          'screen_time': {
            'total_minutes': screenTime.total.inMinutes,
            'apps': [
              for (final usage in screenTime.usages)
                {
                  'name': usage.appName,
                  'minutes': usage.duration.inMinutes,
                  if (usage.appId != null) 'app_id': usage.appId,
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

    return _commentaryFrom(
      score: data['dopagaki_score'] as num?,
      summary: data['summary'] as String,
      advice: data['advice'],
      scoreReason: data['score_reason'] as String?,
      createdAt: data['created_at'] as String?,
    );
  }

  @override
  Future<AiCommentary?> fetchCommentary({
    required ChildProfile child,
    required DateTime date,
  }) async {
    final childId = child.id;
    // Supabase未連携のローカル専用プロフィール。保存済みの講評は存在し得ない。
    if (childId == null) return null;

    final Object? row;
    try {
      row = await Supabase.instance.client
          .from('ai_reviews')
          .select('dopagaki_score, score_reason, comment, advice, created_at')
          .eq('child_id', childId)
          .eq('date', _formatDate(date))
          .maybeSingle();
    } on PostgrestException catch (e) {
      throw AiCommentaryException(AiCommentaryFailure.failed, detail: e.toString());
    }

    // 行が無い = その日の講評はまだ生成されていない(子どもがまだアプリを
    // 開いていない)。エラーではないので null を返し、呼び出し側が
    // 「まだ講評がありません」を出す。
    if (row == null) return null;

    final map = row as Map<String, dynamic>;
    return _commentaryFrom(
      score: map['dopagaki_score'] as num?,
      // DB上の列名は `comment`(Edge Function の応答では `summary`)。
      summary: map['comment'] as String,
      advice: map['advice'],
      scoreReason: map['score_reason'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  /// Edge Function の応答と `ai_reviews` の行、どちらからでも [AiCommentary] を
  /// 組み立てる共通処理。`dopagaki_score` は列がnull許容なので、欠けていれば0扱い。
  AiCommentary _commentaryFrom({
    required num? score,
    required String summary,
    required Object? advice,
    required String? scoreReason,
    required String? createdAt,
  }) {
    final percentage = (score ?? 0).round().clamp(0, 100);
    return AiCommentary(
      summary: summary,
      adviceList: advice is List ? advice.map((e) => e.toString()).toList() : const [],
      generatedAt: createdAt != null
          ? DateTime.tryParse(createdAt)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      scoreReason: scoreReason,
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
