import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'クエスト'),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard_rounded),
            label: 'プレゼント',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: '検索'),
        ],
      ),
    );
  }
}
