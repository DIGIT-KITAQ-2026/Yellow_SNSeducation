import 'package:flutter/widgets.dart';

import 'models/ai_commentary.dart';
import 'models/child_profile.dart';
import 'models/dopagaki_index.dart';
import 'models/screen_time_day.dart';
import 'services/ai_commentary_service.dart';
import 'services/dopagaki_calculator.dart';
import 'services/screen_time_service.dart';

/// アプリ全体で共有する状態。スクリーンタイムとAI講評の対象となる
/// 子ども一覧、取得済みのスクリーンタイム/AI講評をまとめて保持する。
///
/// ログイン・グループ管理機能は別ブランチ(担当メンバー)で実装される想定のため、
/// このブランチでは固定のテスト用の子どもを初期状態として持たせている。
class AppState extends ChangeNotifier {
  AppState({ScreenTimeService? screenTimeService, AiCommentaryService? aiCommentaryService})
      : screenTimeService = screenTimeService ?? MockScreenTimeService(),
        aiCommentaryService = aiCommentaryService ?? MockAiCommentaryService() {
    children = const [
      ChildProfile(id: 'child1', name: 'テストこども1'),
      ChildProfile(id: 'child2', name: 'テストこども2'),
    ];
    selectedChildId = children.first.id;
  }

  final ScreenTimeService screenTimeService;
  final AiCommentaryService aiCommentaryService;

  List<ChildProfile> children = const [];
  String? selectedChildId;

  final Map<String, List<ScreenTimeDay>> _screenTimeCache = {};
  final Map<String, AiCommentary> _commentaryCache = {};
  final Set<String> _loadingScreenTime = {};
  final Set<String> _loadingCommentary = {};

  ChildProfile? get selectedChild {
    final id = selectedChildId;
    if (id == null) return null;
    for (final child in children) {
      if (child.id == id) return child;
    }
    return null;
  }

  List<ScreenTimeDay>? screenTimeFor(String childId) => _screenTimeCache[childId];

  bool isScreenTimeLoading(String childId) => _loadingScreenTime.contains(childId);

  AiCommentary? commentaryFor(String childId) => _commentaryCache[childId];

  bool isCommentaryLoading(String childId) => _loadingCommentary.contains(childId);

  void selectChild(String childId) {
    if (selectedChildId == childId) return;
    selectedChildId = childId;
    notifyListeners();
  }

  /// 指定した子どものスクリーンタイムを未取得なら取得する。
  Future<void> ensureScreenTimeLoaded(String childId) async {
    if (_screenTimeCache.containsKey(childId) || _loadingScreenTime.contains(childId)) {
      return;
    }
    _loadingScreenTime.add(childId);
    notifyListeners();
    try {
      final data = await screenTimeService.fetchRecentScreenTime(childId);
      _screenTimeCache[childId] = data;
    } finally {
      _loadingScreenTime.remove(childId);
      notifyListeners();
    }
  }

  /// 指定した子どものスクリーンタイム/AI講評のキャッシュを破棄し、取得し直す。
  Future<void> refreshScreenTime(String childId) async {
    _screenTimeCache.remove(childId);
    _commentaryCache.remove(childId);
    await ensureScreenTimeLoaded(childId);
  }

  /// 指定した子どもの「昨日」のドパガキ指数。データ未取得なら記録なし扱い。
  DopagakiIndex dopagakiIndexFor(String childId) {
    final days = _screenTimeCache[childId];
    if (days == null || days.isEmpty) return DopagakiIndex.empty;
    return DopagakiCalculator.calculate(days.first);
  }

  /// AI講評を取得済みならキャッシュを返し、無ければ生成してキャッシュする。
  Future<AiCommentary?> getOrGenerateCommentary(String childId) async {
    final cached = _commentaryCache[childId];
    if (cached != null) return cached;
    if (_loadingCommentary.contains(childId)) return null;

    _loadingCommentary.add(childId);
    notifyListeners();
    try {
      await ensureScreenTimeLoaded(childId);
      final days = _screenTimeCache[childId];
      ChildProfile? child;
      for (final c in children) {
        if (c.id == childId) {
          child = c;
          break;
        }
      }
      if (days == null || days.isEmpty || child == null) return null;

      final latest = days.first;
      final index = DopagakiCalculator.calculate(latest);
      final commentary = await aiCommentaryService.generateCommentary(
        child: child,
        screenTime: latest,
        dopagakiIndex: index,
      );
      _commentaryCache[childId] = commentary;
      return commentary;
    } finally {
      _loadingCommentary.remove(childId);
      notifyListeners();
    }
  }
}

/// [AppState] をウィジェットツリーに配布するための InheritedNotifier。
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required super.notifier, required super.child});

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope が見つかりません。MaterialApp の外側で AppScope を配置してください。');
    return scope!.notifier!;
  }
}
