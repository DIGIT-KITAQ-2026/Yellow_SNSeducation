import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/child_profile.dart';
import '../services/app_session.dart';
import 'app_palette.dart';

/// 子どもごとのテーマ選択(サイバー/パステル)を保持・端末に永続化する
/// シングルトン。保護者は常に [AppPalette.parentWhite] を使うため、
/// 選択の保存対象は子どもアカウントのみ。
///
/// [ChildRegistry.replaceGroupChildren] はSupabase再取得のたびに
/// [ChildProfile] インスタンスを作り直すため、テーマ選択は [ChildProfile]
/// に持たせず、ここで独立して(id優先、無ければグループコード+名前で)
/// キー管理する。
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const _prefsPrefix = 'child_theme_kind_';

  final Map<String, AppThemeKind> _kindByKey = {};
  final Set<String> _loadedKeys = {};

  String _keyFor(ChildProfile child) => child.id ?? '${child.groupCode}/${child.name}';

  AppThemeKind kindFor(ChildProfile child) => _kindByKey[_keyFor(child)] ?? AppThemeKind.cyberpunk;

  /// 現在ログイン中のロールに応じたパレット。保護者は常に白基調、
  /// 子どもは選択済みのテーマ(未選択ならサイバー)。
  AppPalette get currentPalette {
    if (!AppSession.instance.isChild) return AppPalette.parentWhite;
    final child = AppSession.instance.childProfile;
    if (child == null) return AppPalette.cyberpunk;
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
}
