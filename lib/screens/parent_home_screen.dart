import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_commentary_card.dart';
import '../widgets/dopagaki_index_card.dart';
import '../widgets/screen_time_charts.dart';

/// スクリーンタイム参照とAIによる講評を表示するホーム画面。
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  String? _lastLoadedChildId;

  void _ensureLoaded(AppState appState) {
    final childId = appState.selectedChildId;
    if (childId == null || childId == _lastLoadedChildId) return;
    _lastLoadedChildId = childId;
    // ensureScreenTimeLoaded synchronously calls notifyListeners(), which must
    // not happen while this widget's own build is still in progress.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appState.ensureScreenTimeLoaded(childId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final childId = appState.selectedChildId;
        if (childId == null) {
          return const Center(child: Text('子どもが選択されていません'));
        }
        _ensureLoaded(appState);

        final days = appState.screenTimeFor(childId);
        final loadingScreenTime = appState.isScreenTimeLoading(childId);
        final dopagakiIndex = appState.dopagakiIndexFor(childId);

        return RefreshIndicator(
          onRefresh: () => appState.refreshScreenTime(childId),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DopagakiIndexCard(index: dopagakiIndex, isLoading: loadingScreenTime),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '先日のスクリーンタイム',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      if (loadingScreenTime || days == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else ...[
                        WeeklyScreenTimeChart(days: days),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'アプリ別の内訳(昨日)',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        AppBreakdownList(day: days.first),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AiCommentaryCard(childId: childId),
            ],
          ),
        );
      },
    );
  }
}
