import 'package:flutter/material.dart';

import '../widgets/futuristic_background.dart';

class SearchBody extends StatelessWidget {
  const SearchBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FuturisticBackground(
      child: Center(
        child: Text(
          '検索画面(準備中)',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
