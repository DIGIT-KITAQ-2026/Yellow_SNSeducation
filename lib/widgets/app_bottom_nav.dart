import 'package:flutter/material.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12103A),
        border: const Border(
          top: BorderSide(color: Color(0xFF33F7FF), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF33F7FF).withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: const Color(0xFF33F7FF),
        unselectedItemColor: Colors.white.withValues(alpha: 0.45),
        items: items,
      ),
    );
  }
}
