import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/child_profile.dart';
import '../services/app_session.dart';
import 'app_palette.dart';

/// 子ども・保護者それぞれのテーマ選択を保持・端末に永続化するシングルトン。
///
/// [ChildRegistry.replaceGroupChildren] はSupabase再取得のたびに
/// [ChildProfile] インスタンスを作り直すため、テーマ選択は [ChildProfile]
/// に持たせず、ここで独立して(id優先、無ければグループコード+名前で)
/// キー管理する。保護者側はログインメール(無ければグループコード)を
/// キーにする。
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const _prefsPrefix = 'child_theme_kind_';
  static const _parentPrefsPrefix = 'parent_theme_kind_';

  final Map<String, AppThemeKind> _kindByKey = {};
  final Set<String> _loadedKeys = {};
  final Map<String, AppThemeKind> _parentKindByKey = {};
  final Set<String> _parentLoadedKeys = {};

  String _keyFor(ChildProfile child) => child.id ?? '${child.groupCode}/${child.name}';

  String _parentKeyFor() =>
      AppSession.instance.currentEmail ?? AppSession.instance.groupCode ?? 'unknown';

  AppThemeKind kindFor(ChildProfile child) => _kindByKey[_keyFor(child)] ?? AppThemeKind.white;

  AppThemeKind kindForParent() => _parentKindByKey[_parentKeyFor()] ?? AppThemeKind.white;

  /// 現在ログイン中のロールに応じたパレット。
  AppPalette get currentPalette {
    if (!AppSession.instance.isChild) return AppPalette.forKind(kindForParent());
    final child = AppSession.instance.childProfile;
    if (child == null) return AppPalette.forKind(AppThemeKind.white);
    return AppPalette.forKind(kindFor(child));
  }

  /// この子どもの保存済みテーマを(未読み込みなら)端末から読み込む。
  Future<void> loadFor(ChildProfile child) async {
    final key = _keyFor(child);
    if (_loadedKeys.contains(key)) return;
    _loadedKeys.add(key);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefsPrefix$key');
    if (raw == null) return;

    for (final kind in AppThemeKind.values) {
      if (kind.name == raw) {
        _kindByKey[key] = kind;
        notifyListeners();
        return;
      }
    }
  }

  Future<void> setKind(ChildProfile child, AppThemeKind kind) async {
    final key = _keyFor(child);
    _kindByKey[key] = kind;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefsPrefix$key', kind.name);
  }

  /// 保護者の保存済みテーマを(未読み込みなら)端末から読み込む。
  Future<void> loadForParent() async {
    final key = _parentKeyFor();
    if (_parentLoadedKeys.contains(key)) return;
    _parentLoadedKeys.add(key);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_parentPrefsPrefix$key');
    if (raw == null) return;

    for (final kind in AppThemeKind.values) {
      if (kind.name == raw) {
        _parentKindByKey[key] = kind;
        notifyListeners();
        return;
      }
    }
  }

  Future<void> setKindForParent(AppThemeKind kind) async {
    final key = _parentKeyFor();
    _parentKindByKey[key] = kind;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_parentPrefsPrefix$key', kind.name);
  }
}
