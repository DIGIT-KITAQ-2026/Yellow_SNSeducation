import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final palette = ThemeController.instance.currentPalette;
        return Container(
          decoration: BoxDecoration(
            color: palette.navBackground,
            border: Border(top: BorderSide(color: palette.navBorder, width: 1)),
            boxShadow: [
              BoxShadow(
                color: palette.isDark
                    ? palette.navBorder.withValues(alpha: 0.25)
                    : palette.cardShadow.withValues(alpha: 0.3),
                blurRadius: palette.isDark ? 12 : 8,
                spreadRadius: palette.isDark ? -2 : 0,
                offset: palette.isDark ? Offset.zero : const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTap,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: palette.navSelected,
            unselectedItemColor: palette.navUnselected,
            items: items,
          ),
        );
      },
    );
  }
}
