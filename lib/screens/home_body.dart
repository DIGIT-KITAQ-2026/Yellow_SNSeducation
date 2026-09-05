import 'package:flutter/material.dart';

import '../widgets/futuristic_background.dart';
import '../widgets/glass_card.dart';

class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FuturisticBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _DopamineIndexCard(),
            SizedBox(height: 16),
            _ScreenTimePlaceholderCard(),
            SizedBox(height: 16),
            _AiCommentCard(),
          ],
        ),
      ),
    );
  }
}

class _DopamineIndexCard extends StatelessWidget {
  const _DopamineIndexCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          const Text(
            '昨日のドパガキ指数',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const Spacer(),
          Container(
            width: 56,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF33F7FF), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 8),
          const Text('％', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}

class _ScreenTimePlaceholderCard extends StatelessWidget {
  const _ScreenTimePlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      height: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '先日のスクリーンタイム',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const Spacer(),
          Center(
            child: Icon(Icons.bar_chart_rounded, size: 40,
                color: const Color(0xFF33F7FF).withValues(alpha: 0.6)),
          ),
          const Spacer(),
          Text(
            'アプリ別のスクリーンタイムをグラフで表示予定',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AiCommentCard extends StatelessWidget {
  const _AiCommentCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFFF3DAE), size: 20),
          const SizedBox(width: 8),
          const Text(
            'AIによる講評',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
