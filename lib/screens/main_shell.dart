import 'package:flutter/material.dart';

import '../widgets/account_bar.dart';
import '../widgets/app_bottom_nav.dart';
import 'gift_body.dart';
import 'home_body.dart';
import 'quest_body.dart';
import 'search_body.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A24),
      body: SafeArea(
        child: Column(
          children: [
            const AccountBar(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: const [
                  HomeBody(),
                  QuestBody(),
                  GiftBody(),
                  SearchBody(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
      ),
    );
  }
}
