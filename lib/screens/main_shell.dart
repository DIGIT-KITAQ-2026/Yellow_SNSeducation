import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../theme/theme_controller.dart';
import '../widgets/account_bar.dart';
import '../widgets/app_bottom_nav.dart';
import 'activity_body.dart';
import 'gift_body.dart';
import 'home_body.dart';
import 'quest_body.dart';

/// ボトムナビの1タブ。アイコン・ラベルと表示する body をひとまとめにして、
/// AppBottomNav の items と IndexedStack の children が位置ズレしないようにする。
class _NavTab {
  const _NavTab({required this.icon, required this.label, required this.body});

  final IconData icon;
  final String label;
  final Widget body;
}

const _commonTabs = <_NavTab>[
  _NavTab(icon: Icons.home_rounded, label: 'ホーム', body: HomeBody()),
  _NavTab(icon: Icons.list_alt_rounded, label: 'クエスト', body: QuestBody()),
  _NavTab(icon: Icons.card_giftcard_rounded, label: 'プレゼント', body: GiftBody()),
];

// 周辺アクティビティは子ども専用。親には出さない(タブ数が3になる)。
const _childTabs = <_NavTab>[
  ..._commonTabs,
  _NavTab(icon: Icons.explore_rounded, label: 'おでかけ', body: ActivityBody()),
];

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    AppSession.instance.addListener(_handleSessionChange);
    ThemeController.instance.addListener(_handleSessionChange);
    _ensureThemeLoaded();
  }

  @override
  void dispose() {
    AppSession.instance.removeListener(_handleSessionChange);
    ThemeController.instance.removeListener(_handleSessionChange);
    super.dispose();
  }

  void _handleSessionChange() {
    _ensureThemeLoaded();
    setState(() {});
  }

  void _ensureThemeLoaded() {
    final child = AppSession.instance.childProfile;
    if (AppSession.instance.isChild && child != null) {
      ThemeController.instance.loadFor(child);
    } else if (!AppSession.instance.isChild) {
      ThemeController.instance.loadForParent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = AppSession.instance.isChild ? _childTabs : _commonTabs;
    // ロールが親に変わってタブが減った場合でも範囲外を選ばないようにする。
    // 保存する _index はクランプしない(子に戻ったとき選択位置が復元される)。
    final index = _index.clamp(0, tabs.length - 1);
    final palette = ThemeController.instance.currentPalette;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            const AccountBar(),
            Expanded(
              child: IndexedStack(
                index: index,
                children: [for (final tab in tabs) tab.body],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: index,
        onTap: (i) => setState(() => _index = i),
        items: [
          for (final tab in tabs)
            BottomNavigationBarItem(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}
