import 'package:flutter/material.dart';

/// 子どもが選べるテーマの種類。保護者は常に [AppPalette.parentWhite] になる
/// ため、ここには含めない。
enum AppThemeKind { cyberpunk, pastel, ocean, natural }

/// 画面全体の配色一式。背景・カード・ナビゲーション・文字色をまとめて持つ。
///
/// [GlassCard] / [FuturisticBackground] / [AppBottomNav] など共通部品と、
/// 各画面のテキスト・アイコン色の両方がこのパレットを参照する。
class AppPalette {
  const AppPalette({
    required this.isDark,
    required this.scaffoldBackground,
    required this.backgroundGradient,
    required this.showSkyline,
    required this.surface,
    required this.surfaceAlt,
    required this.cardBorder,
    required this.cardShadow,
    required this.accent,
    required this.accentOn,
    required this.accentSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.danger,
    required this.warning,
    required this.good,
    required this.navBackground,
    required this.navBorder,
    required this.navSelected,
    required this.navUnselected,
    required this.dialogBackground,
    required this.inputFill,
    required this.inputBorder,
  });

  /// 白文字/濃色文字のどちらを基調にするか。
  final bool isDark;

  final Color scaffoldBackground;
  /// [FuturisticBackground] のグラデーション(上→下)。
  final List<Color> backgroundGradient;
  /// サイバーパンク風のグリッド・星を描画するか(パステル/白では描かない)。
  final bool showSkyline;

  final Color surface;
  final Color surfaceAlt;
  final Color cardBorder;
  final Color cardShadow;

  final Color accent;
  /// アクセント色で塗った面(ボタンなど)の上に乗せる文字色。
  final Color accentOn;
  final Color accentSecondary;

  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  final Color danger;
  final Color warning;
  final Color good;

  final Color navBackground;
  final Color navBorder;
  final Color navSelected;
  final Color navUnselected;

  final Color dialogBackground;
  final Color inputFill;
  final Color inputBorder;

  static AppPalette forKind(AppThemeKind kind) {
    switch (kind) {
      case AppThemeKind.cyberpunk:
        return cyberpunk;
      case AppThemeKind.pastel:
        return pastel;
      case AppThemeKind.ocean:
        return ocean;
      case AppThemeKind.natural:
        return natural;
    }
  }

  /// 現在の見た目(ネオン・サイバーパンク)をそのままパレット化したもの。
  static const cyberpunk = AppPalette(
    isDark: true,
    scaffoldBackground: Color(0xFF0B0A24),
    backgroundGradient: [Color(0xFF0B0A24), Color(0xFF1A0F45), Color(0xFF3A1264)],
    showSkyline: true,
    surface: Color(0xFF12103A),
    surfaceAlt: Color(0xFF1B1854),
    cardBorder: Color(0xFF33F7FF),
    cardShadow: Color(0xFF33F7FF),
    accent: Color(0xFF33F7FF),
    accentOn: Color(0xFF0B0A24),
    accentSecondary: Color(0xFFFF3DAE),
    textPrimary: Colors.white,
    textSecondary: Color(0xB3FFFFFF),
    textDisabled: Color(0x61FFFFFF),
    danger: Color(0xFFEF6461),
    warning: Color(0xFFF5C451),
    good: Color(0xFF4ADE80),
    navBackground: Color(0xFF12103A),
    navBorder: Color(0xFF33F7FF),
    navSelected: Color(0xFF33F7FF),
    navUnselected: Color(0x8AFFFFFF),
    dialogBackground: Color(0xFF242428),
    inputFill: Color(0x0FFFFFFF),
    inputBorder: Color(0x33FFFFFF),
  );

  /// 女子ウケを狙ったパステル・ピンク基調のライトテーマ。
  static const pastel = AppPalette(
    isDark: false,
    scaffoldBackground: Color(0xFFFFF5F9),
    backgroundGradient: [Color(0xFFFFF0F6), Color(0xFFFCEBFF), Color(0xFFF1E9FF)],
    showSkyline: false,
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFFE1EE),
    cardBorder: Color(0xFFFFC3DE),
    cardShadow: Color(0xFFFFB3D1),
    accent: Color(0xFFFF6FA5),
    accentOn: Colors.white,
    accentSecondary: Color(0xFFB388FF),
    textPrimary: Color(0xFF4A2E3D),
    textSecondary: Color(0xFF8C6B7C),
    textDisabled: Color(0xFFC7B3BE),
    danger: Color(0xFFE0545A),
    warning: Color(0xFFE0A83E),
    good: Color(0xFF3FB582),
    navBackground: Color(0xFFFFFFFF),
    navBorder: Color(0xFFFFD6E8),
    navSelected: Color(0xFFFF6FA5),
    navUnselected: Color(0xFFBBA6B3),
    dialogBackground: Color(0xFFFFFFFF),
    inputFill: Color(0xFFFFF0F6),
    inputBorder: Color(0xFFFFD6E8),
  );

  /// 🌊 Ocean: 「すっきり爽やか!」青・水色・白基調。ロボットの水色とも相性がいい。
  static const ocean = AppPalette(
    isDark: false,
    scaffoldBackground: Color(0xFFEAF6FB),
    backgroundGradient: [Color(0xFFF2FBFF), Color(0xFFDDF1FB), Color(0xFFCCE8FA)],
    showSkyline: false,
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE1F1FA),
    cardBorder: Color(0xFFBBDFF0),
    cardShadow: Color(0xFFA9D7EE),
    accent: Color(0xFF2E8FD9),
    accentOn: Colors.white,
    accentSecondary: Color(0xFF4FC3D9),
    textPrimary: Color(0xFF16324F),
    textSecondary: Color(0xFF4E7290),
    textDisabled: Color(0xFFA9C0D2),
    danger: Color(0xFFE0545A),
    warning: Color(0xFFD79B3E),
    good: Color(0xFF2FA98A),
    navBackground: Color(0xFFFFFFFF),
    navBorder: Color(0xFFBBDFF0),
    navSelected: Color(0xFF2E8FD9),
    navUnselected: Color(0xFF9DB8CB),
    dialogBackground: Color(0xFFFFFFFF),
    inputFill: Color(0xFFEFFAFF),
    inputBorder: Color(0xFFBBDFF0),
  );

  /// 🌿 Natural: 「ゆったり、安心」緑・クリーム・ベージュ基調。
  static const natural = AppPalette(
    isDark: false,
    scaffoldBackground: Color(0xFFFAF6EC),
    backgroundGradient: [Color(0xFFFBF8EF), Color(0xFFF3EEDD), Color(0xFFE8F0DE)],
    showSkyline: false,
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0EAD6),
    cardBorder: Color(0xFFDCCFA0),
    cardShadow: Color(0xFFD3C7A0),
    accent: Color(0xFF4F9A4A),
    accentOn: Colors.white,
    accentSecondary: Color(0xFFE0B15A),
    textPrimary: Color(0xFF3B3223),
    textSecondary: Color(0xFF7A6F55),
    textDisabled: Color(0xFFC9BFA0),
    danger: Color(0xFFD1544F),
    warning: Color(0xFFD79B2E),
    good: Color(0xFF3F8F52),
    navBackground: Color(0xFFFFFFFF),
    navBorder: Color(0xFFE3D9B8),
    navSelected: Color(0xFF4F9A4A),
    navUnselected: Color(0xFFB4A98A),
    dialogBackground: Color(0xFFFFFFFF),
    inputFill: Color(0xFFF6F1E1),
    inputBorder: Color(0xFFE3D9B8),
  );

  /// 保護者用の落ち着いた白基調テーマ。
  static const parentWhite = AppPalette(
    isDark: false,
    scaffoldBackground: Color(0xFFF7F8FA),
    backgroundGradient: [Color(0xFFFFFFFF), Color(0xFFF7F8FA)],
    showSkyline: false,
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFF1F4),
    cardBorder: Color(0xFFE2E5EA),
    cardShadow: Color(0xFFD8DCE3),
    accent: Color(0xFF2DD4BF),
    accentOn: Colors.white,
    accentSecondary: Color(0xFF6C7BFF),
    textPrimary: Color(0xFF11151B),
    textSecondary: Color(0xFF5B6472),
    textDisabled: Color(0xFFAEB4BD),
    danger: Color(0xFFEF6461),
    warning: Color(0xFFD79B2E),
    good: Color(0xFF2FA96A),
    navBackground: Color(0xFFFFFFFF),
    navBorder: Color(0xFFE2E5EA),
    navSelected: Color(0xFF2DD4BF),
    navUnselected: Color(0xFF9CA5B1),
    dialogBackground: Color(0xFFFFFFFF),
    inputFill: Color(0xFFF3F4F6),
    inputBorder: Color(0xFFDEE1E6),
  );
}
