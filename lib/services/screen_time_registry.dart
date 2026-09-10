import 'package:flutter/foundation.dart';

import '../models/ai_commentary.dart';
import '../models/child_profile.dart';
import '../models/dopagaki_index.dart';
import '../models/screen_time_day.dart';
import 'ai_commentary_service.dart';
import 'device_screen_time_service.dart';
import 'screen_time_service.dart';
import 'supabase_ai_commentary_service.dart';

/// スクリーンタイムとAI講評の取得状況・キャッシュを保持するシングルトン。
///
/// [ChildRegistry] や [AppSession] と同じ「ChangeNotifier のシングルトン +
/// addListener/setState」の流儀に合わせている。子ども一覧・選択そのものは
/// [ChildRegistry] が担うため、このクラスは子どもごとのスクリーンタイム/
/// AI講評のキャッシュだけを持つ。
class ScreenTimeRegistry extends ChangeNotifier {
  ScreenTimeRegistry._();

  static final ScreenTimeRegistry instance = ScreenTimeRegistry._();

  ScreenTimeService screenTimeService = DeviceScreenTimeService();
  AiCommentaryService aiCommentaryService = const SupabaseAiCommentaryService();

  final Map<String, List<ScreenTimeDay>> _screenTimeCache = {};
  final Map<String, AiCommentary> _commentaryCache = {};
  final Map<String, String> _screenTimeErrors = {};
  final Set<String> _screenTimePermissionNeeded = {};
  final Map<String, String> _commentaryErrors = {};

  /// [refreshScreenTime] を通ったキー。次の [getOrGenerateCommentary] で
  /// サーバ側の講評キャッシュも無視して作り直させるために覚えておく。
  final Set<String> _commentaryNeedsRegenerate = {};
  final Set<String> _loadingScreenTime = {};
  final Set<String> _loadingCommentary = {};

  /// Supabase連携済みなら `profiles.id`(グループを跨いでも一意)をキーにする。
  /// ローカル専用のダミー作成(id無し)の場合のみ、グループコード+名前で代用する。
  String _keyFor(ChildProfile child) => child.id ?? '${child.groupCode}/${child.name}';

  List<ScreenTimeDay>? screenTimeFor(ChildProfile child) => _screenTimeCache[_keyFor(child)];

  bool isScreenTimeLoading(ChildProfile child) => _loadingScreenTime.contains(_keyFor(child));

  /// 直近の `ensureScreenTimeLoaded` が失敗した場合の、画面にそのまま出せる
  /// 日本語メッセージ。成功時・未リクエスト時は null。
  String? screenTimeErrorFor(ChildProfile child) => _screenTimeErrors[_keyFor(child)];

  /// スクリーンタイム取得の失敗理由が「使用状況へのアクセス」未許可かどうか。
  /// true の場合、画面は再試行ではなく設定を開くボタンを出す。
  bool screenTimeNeedsPermission(ChildProfile child) =>
      _screenTimePermissionNeeded.contains(_keyFor(child));

  AiCommentary? commentaryFor(ChildProfile child) => _commentaryCache[_keyFor(child)];

  bool isCommentaryLoading(ChildProfile child) => _loadingCommentary.contains(_keyFor(child));

  /// 直近の `getOrGenerateCommentary` が失敗した場合の、画面にそのまま出せる
  /// 日本語メッセージ。成功時・未リクエスト時は null。
  String? commentaryErrorFor(ChildProfile child) => _commentaryErrors[_keyFor(child)];

  /// 指定した子どものスクリーンタイムを未取得なら取得する。
  Future<void> ensureScreenTimeLoaded(ChildProfile child) async {
    final key = _keyFor(child);
    if (_screenTimeCache.containsKey(key) || _loadingScreenTime.contains(key)) {
      return;
    }
    _loadingScreenTime.add(key);
    notifyListeners();
    try {
      final data = await screenTimeService.fetchRecentScreenTime(key);
      _screenTimeCache[key] = data;
      _screenTimeErrors.remove(key);
      _screenTimePermissionNeeded.remove(key);
    } on ScreenTimeUnavailableException catch (e) {
      _screenTimeErrors[key] = e.message;
      if (e.reason == ScreenTimeUnavailableReason.permissionRequired) {
        _screenTimePermissionNeeded.add(key);
      } else {
        _screenTimePermissionNeeded.remove(key);
      }
    } catch (_) {
      _screenTimeErrors[key] = 'スクリーンタイムを取得できませんでした。もう一度お試しください';
      _screenTimePermissionNeeded.remove(key);
    } finally {
      _loadingScreenTime.remove(key);
      notifyListeners();
    }
  }

  /// 「使用状況へのアクセス」の設定画面を開き、戻ってきたら再取得する。
  Future<void> requestScreenTimePermission(ChildProfile child) async {
    final service = screenTimeService;
    if (service is DeviceScreenTimeService) {
      await service.openPermissionSettings();
    }
    await refreshScreenTime(child);
  }

  /// 指定した子どものスクリーンタイム/AI講評のキャッシュを破棄し、取得し直す。
  Future<void> refreshScreenTime(ChildProfile child) async {
    final key = _keyFor(child);
    _screenTimeCache.remove(key);
    _commentaryCache.remove(key);
    _commentaryNeedsRegenerate.add(key);
    await ensureScreenTimeLoaded(child);
  }

  /// 指定した子どもの「昨日」のドパガキ指数。AI講評とセットで算出されるため、
  /// 講評未生成の間は「未算出」、スクリーンタイム自体が無ければ「記録なし」を返す。
  DopagakiIndex dopagakiIndexFor(ChildProfile child) {
    final commentary = _commentaryCache[_keyFor(child)];
    if (commentary != null) return commentary.dopagakiIndex;

    final days = _screenTimeCache[_keyFor(child)];
    if (days == null || days.isEmpty) return DopagakiIndex.empty;
    return DopagakiIndex.notGenerated;
  }

  /// AI講評を取得済みならキャッシュを返し、無ければ生成してキャッシュする。
  Future<AiCommentary?> getOrGenerateCommentary(ChildProfile child) async {
    final key = _keyFor(child);
    final cached = _commentaryCache[key];
    if (cached != null) return cached;
    if (_loadingCommentary.contains(key)) return null;

    _loadingCommentary.add(key);
    _commentaryErrors.remove(key);
    notifyListeners();
    try {
      await ensureScreenTimeLoaded(child);
      final screenTimeError = _screenTimeErrors[key];
      if (screenTimeError != null) {
        _commentaryErrors[key] = screenTimeError;
        return null;
      }
      final days = _screenTimeCache[key];
      if (days == null || days.isEmpty) return null;

      final latest = days.first;
      final commentary = await aiCommentaryService.generateCommentary(
        child: child,
        screenTime: latest,
        force: _commentaryNeedsRegenerate.remove(key),
      );
      _commentaryCache[key] = commentary;
      return commentary;
    } on AiCommentaryException catch (e) {
      _commentaryErrors[key] = e.message;
      return null;
    } catch (_) {
      _commentaryErrors[key] = '講評を取得できませんでした。しばらくしてから、もう一度お試しください';
      return null;
    } finally {
      _loadingCommentary.remove(key);
      notifyListeners();
    }
  }

  /// サインアウト時にキャッシュを全て破棄する。
  void clear() {
    _screenTimeCache.clear();
    _commentaryCache.clear();
    _screenTimeErrors.clear();
    _screenTimePermissionNeeded.clear();
    _commentaryErrors.clear();
    _commentaryNeedsRegenerate.clear();
    _loadingScreenTime.clear();
    _loadingCommentary.clear();
    notifyListeners();
  }
}
