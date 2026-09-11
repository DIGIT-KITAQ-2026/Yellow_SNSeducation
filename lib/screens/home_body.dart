import 'package:flutter/material.dart';

import '../models/child_profile.dart';
import '../services/app_session.dart';
import '../services/child_registry.dart';
import '../services/screen_time_registry.dart';
import '../theme/theme_controller.dart';
import '../widgets/ai_commentary_card.dart';
import '../widgets/dopagaki_index_card.dart';
import '../widgets/futuristic_background.dart';
import '../widgets/screen_time_card.dart';
import '../widgets/session_refresh_indicator.dart';

class HomeBody extends StatefulWidget {
  const HomeBody({super.key});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  ChildProfile? _lastLoadedChild;

  @override
  void initState() {
    super.initState();
    ChildRegistry.instance.addListener(_handleChange);
    AppSession.instance.addListener(_handleChange);
    ScreenTimeRegistry.instance.addListener(_handleChange);
    ThemeController.instance.addListener(_handleChange);
  }

  @override
  void dispose() {
    ChildRegistry.instance.removeListener(_handleChange);
    AppSession.instance.removeListener(_handleChange);
    ScreenTimeRegistry.instance.removeListener(_handleChange);
    ThemeController.instance.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() => setState(() {});

  ChildProfile? _resolveChild() {
    return AppSession.instance.isChild
        ? AppSession.instance.childProfile
        : ChildRegistry.instance.selectedInGroup(AppSession.instance.groupCode);
  }

  void _ensureLoaded(ChildProfile child) {
    if (identical(child, _lastLoadedChild)) return;
    _lastLoadedChild = child;
    // ensureScreenTimeLoaded synchronously calls notifyListeners(), which must
    // not happen while this widget's own build is still in progress.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ScreenTimeRegistry.instance.ensureScreenTimeLoaded(child);
      // ドパガキ指数はAI講評とセットで算出されるため、ホーム画面表示時点で
      // 「講評を見る」を押さなくても指数が出ているように、ここで先読みする。
      ScreenTimeRegistry.instance.getOrGenerateCommentary(child);
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = _resolveChild();
    final palette = ThemeController.instance.currentPalette;

    return FuturisticBackground(
      child: child == null
          ? Center(
              child: Text('子供が選択されていません', style: TextStyle(color: palette.textPrimary)),
            )
          : Builder(
              builder: (context) {
                _ensureLoaded(child);
                final registry = ScreenTimeRegistry.instance;
                final days = registry.screenTimeFor(child);
                final loadingScreenTime = registry.isScreenTimeLoading(child);
                final screenTimeError = registry.screenTimeErrorFor(child);
                final needsPermission = registry.screenTimeNeedsPermission(child);
                final dopagakiIndex = registry.dopagakiIndexFor(child);

                return SessionRefreshIndicator(
                  onAlsoRefresh: () => registry.refreshScreenTime(child),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DopagakiIndexCard(
                          index: dopagakiIndex,
                          isLoading: loadingScreenTime,
                          isParent: !AppSession.instance.isChild,
                        ),
                        const SizedBox(height: 16),
                        ScreenTimeCard(
                          days: days,
                          isLoading: loadingScreenTime,
                          error: screenTimeError,
                          needsPermission: needsPermission,
                          onRetry: () => registry.refreshScreenTime(child),
                          onOpenSettings: () => registry.requestScreenTimePermission(child),
                        ),
                        const SizedBox(height: 16),
                        AiCommentaryCard(child: child),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
