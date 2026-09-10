import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_suggestion.dart';
import '../models/quest_item.dart';
import 'geolocator_location_service.dart';
import 'location_service.dart';

/// 親の通知ベルに出す、未処理のアクティビティ申請1件分の生タプル。
/// service / session_bridge / auth_gate の3ファイルで同じ6フィールドの
/// レコードを書くことになるため、typedef で名前を付けている。
typedef PendingActivityRequestRow = ({
  String id,
  String childId,
  String title,
  String detail,
  String? suggestionId,
  DateTime requestedAt,
});

enum ActivitySuggestFailure { quotaExceeded, rateLimited, notConfigured, failed }

/// `activity-suggest` Edge Function が失敗を返したときの、画面にそのまま出せる
/// 日本語メッセージ付き例外。[LocationUnavailableException] と同じ形。
///
/// [detail] は開発者向けの原因情報で、画面には出さない。
class ActivitySuggestException implements Exception {
  const ActivitySuggestException(this.failure, {this.detail});

  /// `FunctionException.details` から失敗理由を判定する。
  ///
  /// 判定は必ず body の `error` 値で行い、HTTP ステータスでは判定しない。
  /// 自前のレートリミットも Gemini のクォータ超過もどちらも 429 を返すため、
  /// ステータスだけでは区別できない。`details` が Map でない(HTMLエラーページ・
  /// 空ボディ・ゲートウェイの 401/502 など)場合や `error` キーが無い/未知の値の
  /// 場合は、原因不明の失敗として扱う(誤ってクォータ超過と伝える方が有害)。
  factory ActivitySuggestException.fromFunctionException(FunctionException e) {
    final details = e.details;
    final error = details is Map ? details['error'] : null;
    return ActivitySuggestException(_failureFromErrorCode(error), detail: e.toString());
  }

  /// 200応答の body に載る `error` 値からの変換 (`gemini_not_configured` はこの経路)。
  factory ActivitySuggestException.fromErrorCode(Object? error) {
    return ActivitySuggestException(_failureFromErrorCode(error), detail: '$error');
  }

  static ActivitySuggestFailure _failureFromErrorCode(Object? error) => switch (error) {
        'gemini_quota_exceeded' => ActivitySuggestFailure.quotaExceeded,
        'rate_limited' => ActivitySuggestFailure.rateLimited,
        'gemini_not_configured' => ActivitySuggestFailure.notConfigured,
        _ => ActivitySuggestFailure.failed,
      };

  final ActivitySuggestFailure failure;
  final String? detail;

  String get message => switch (failure) {
        ActivitySuggestFailure.quotaExceeded =>
          'AIの提案が今日の上限に達しました。明日またお試しください',
        ActivitySuggestFailure.rateLimited =>
          '今日の検索回数の上限に達しました。明日またお試しください',
        ActivitySuggestFailure.notConfigured =>
          '現在AIの提案は利用できません。おうちの方にお知らせください',
        ActivitySuggestFailure.failed =>
          '提案を取得できませんでした。しばらくしてから、もう一度お試しください',
      };

  @override
  String toString() => 'ActivitySuggestException($failure${detail != null ? ': $detail' : ''})';
}

/// Thin wrapper over the Supabase client for everything activity-related
/// (`activity_suggestions` / `activity_requests` + `activity-suggest` Edge
/// Function). Holds no state of its own, same shape as [QuestService].
class ActivityService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 現在地の取得元。既定が本実装なので `main.dart` での差し替えは不要。
  /// テストだけが自前の Fake を代入する(`flutter test` はプラグインを持たないため)。
  static LocationService locationService = GeolocatorLocationService();

  /// `activity-suggest` Edge Function を呼び、周辺アクティビティ候補を得る。
  static Future<List<ActivitySuggestion>> fetchSuggestions({
    required String childId,
    required double latitude,
    required double longitude,
    bool force = false,
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'activity-suggest',
        body: {
          'child_id': childId,
          'latitude': latitude,
          'longitude': longitude,
          if (force) 'force': true,
        },
      );
    } on FunctionException catch (e) {
      throw ActivitySuggestException.fromFunctionException(e);
    }

    final data = response.data;
    if (data is! Map) {
      throw const FormatException('unexpected activity-suggest response shape');
    }
    if (data['error'] != null) {
      throw ActivitySuggestException.fromErrorCode(data['error']);
    }

    return [
      for (final row in data['suggestions'] as List)
        ActivitySuggestion.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// 子どもが「行きたい」を申請する。RLS `activity_requests_insert` が
  /// `child_id = auth.uid()` を強制するので、自分の分しか作れない。
  static Future<String> requestActivity({
    required String childId,
    required String title,
    String detail = '',
    String? suggestionId,
  }) async {
    final row = await _client
        .from('activity_requests')
        .insert({
          'child_id': childId,
          'title': title,
          if (detail.isNotEmpty) 'description': detail,
          if (suggestionId != null) 'suggestion_id': suggestionId,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Pending (未処理) のアクティビティ申請一覧、親の通知ベル用。
  ///
  /// `groupId` を引数に取らないのは意図的。RLS `activity_requests_select` が
  /// 「親なら同一グループ全員分」に既に絞ってくれる。加えて `activity_requests`
  /// は `profiles` への外部キーを2本(`child_id` と `decided_by`)持つため、
  /// `QuestService.fetchPendingRequests` のような埋め込みJOIN(`profiles!inner`)
  /// を書くと PostgREST が関係を一意に決められずエラーになる。RLS任せのほうが
  /// 単純で壊れにくいのでこちらを採る。
  static Future<List<PendingActivityRequestRow>> fetchPendingRequests() async {
    final rows = await _client
        .from('activity_requests')
        .select('id, child_id, title, description, suggestion_id, requested_at')
        .eq('status', 'pending')
        .order('requested_at');

    return [
      for (final row in rows as List)
        (
          id: row['id'] as String,
          childId: row['child_id'] as String,
          title: row['title'] as String,
          detail: row['description'] as String? ?? '',
          suggestionId: row['suggestion_id'] as String?,
          requestedAt: DateTime.parse(row['requested_at'] as String).toLocal(),
        ),
    ];
  }

  /// 申請を承認する。`approve_activity_request` は生成した `tasks.id` を返す
  /// ので、その id で [QuestItem] を組み立てて返す(再取得は不要)。
  static Future<QuestItem> approveRequest({
    required String requestId,
    required int points,
    required String title,
    required String detail,
  }) async {
    final taskId = await _client.rpc(
      'approve_activity_request',
      params: {'request_id': requestId, 'points': points},
    ) as String;
    return QuestItem(id: taskId, title: title, points: points, detail: detail);
  }

  static Future<void> rejectRequest(String requestId) {
    return _client.rpc('reject_activity_request', params: {'request_id': requestId});
  }
}
