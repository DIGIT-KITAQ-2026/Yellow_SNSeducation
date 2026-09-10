import 'package:flutter/material.dart';

/// Android のパッケージ名から、アプリ別内訳グラフの表示色を引くカタログ。
///
/// 既知アプリはブランドに寄せた固定色を持ち、カタログに無いアプリ(ランチャーや
/// マイナーなアプリなど)はパッケージ名から決定的に色を生成する。
///
/// 「ドパガキ対象アプリかどうか」の判定はここでは持たない。アプリは次々に
/// 増えるためカタログでは追いつかず、判定は AI 講評(`ai-review` Edge
/// Function)側でアプリ名とパッケージ名から都度行っている。
class AppCatalog {
  const AppCatalog._();

  static const Map<String, Color> _knownColors = {
    'com.google.android.youtube': Color(0xFFFF5C5C),
    'com.zhiliaoapp.musically': Color(0xFFEF4D8C), // TikTok
    'com.ss.android.ugc.trill': Color(0xFFEF4D8C), // TikTok (別リージョン向け)
    'com.zhiliaoapp.musically.go': Color(0xFFEF4D8C),
    'com.instagram.android': Color(0xFFB06AF2),
    'com.twitter.android': Color(0xFF60A5FA),
    'com.facebook.katana': Color(0xFF3B82F6),
    'com.snapchat.android': Color(0xFFF5E94A),
    'jp.naver.line.android': Color(0xFF4ADE80),
    'com.discord': Color(0xFF7C6AF2),
    'com.supercell.clashroyale': Color(0xFFF5A524),
    'com.roblox.client': Color(0xFFF5A524),
    'com.mojang.minecraftpe': Color(0xFFF5A524),
  };

  static Color colorFor(String packageName) {
    final known = _knownColors[packageName];
    if (known != null) return known;

    // パッケージ名から決定的に生成する(同じアプリなら常に同じ色になる)。
    final hue = (packageName.hashCode.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.55, 0.62).toColor();
  }
}
