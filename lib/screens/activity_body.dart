import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/activity_suggestion.dart';
import '../services/activity_request_registry.dart';
import '../services/activity_service.dart';
import '../services/app_session.dart';
import '../services/location_service.dart';
import '../theme/app_palette.dart';
import '../theme/theme_controller.dart';
import '../widgets/futuristic_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/session_refresh_indicator.dart';

/// 周辺アクティビティ提案画面(子どもタブ専用)。
///
/// 重要: 初回表示で自動検索しない。`IndexedStack` は全タブを起動時に build する
/// ため、ここで自動検索すると「ログインしただけで権限ダイアログ + Gemini課金」が
/// 走ってしまう。検索は必ずユーザーのボタン操作を起点にする。
class ActivityBody extends StatefulWidget {
  const ActivityBody({super.key});

  @override
  State<ActivityBody> createState() => _ActivityBodyState();
}

class _ActivityBodyState extends State<ActivityBody> {
  bool _busy = false;
  bool _searched = false;
  String? _notice; // 権限拒否などの案内文
  List<ActivitySuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    AppSession.instance.addListener(_handleRegistryChange);
    ActivityRequestRegistry.instance.addListener(_handleRegistryChange);
    ThemeController.instance.addListener(_handleRegistryChange);
  }

  @override
  void dispose() {
    AppSession.instance.removeListener(_handleRegistryChange);
    ActivityRequestRegistry.instance.removeListener(_handleRegistryChange);
    ThemeController.instance.removeListener(_handleRegistryChange);
    super.dispose();
  }

  void _handleRegistryChange() => setState(() {});

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _search({bool force = false}) async {
    if (_busy) return;
    final profile = AppSession.instance.childProfile;
    if (profile?.id == null) return;

    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final point = await ActivityService.locationService.currentPosition();
      final list = await ActivityService.fetchSuggestions(
        childId: profile!.id!,
        latitude: point.latitude,
        longitude: point.longitude,
        force: force,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = list;
        _searched = true;
      });
    } on LocationUnavailableException catch (e) {
      if (!mounted) return;
      setState(() => _notice = e.message);
    } on ActivitySuggestException catch (e) {
      if (!mounted) return;
      setState(() => _notice = e.message);
    } catch (_) {
      _showError('検索に失敗しました。通信状況を確認してください');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request(ActivitySuggestion suggestion) async {
    if (_busy) return;
    final profile = AppSession.instance.childProfile;
    if (profile == null) return;

    setState(() => _busy = true);
    try {
      await ActivityRequestRegistry.instance.addRequest(profile, suggestion);
      if (!mounted) return;
      // 自分の操作の控えはスナックバーで足りる。お知らせ欄は「保護者から
      // 届いたもの」だけを並べる。
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('おでかけ申請を送りました')),
      );
    } catch (_) {
      _showError('送信に失敗しました。もう一度お試しください');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 親が万一到達したときの防御。通常は MainShell がこのタブ自体を出さない。
    if (!AppSession.instance.isChild) {
      return const FuturisticBackground(child: SizedBox.shrink());
    }

    final palette = ThemeController.instance.currentPalette;

    return FuturisticBackground(
      child: SessionRefreshIndicator(
        // まだ「探す」を押していないうちは場所検索をしない(位置情報ダイアログと
        // Gemini呼び出しを勝手に走らせない)。検索済みなら取り直す。
        onAlsoRefresh: _searched ? () => _search(force: true) : null,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'SNSの時間のかわりに、近くで無料で楽しめることを探そう',
                      style: TextStyle(fontWeight: FontWeight.bold, color: palette.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AIの提案です。おでかけ前におうちの人と確認してください。',
                      style: TextStyle(fontSize: 11, color: palette.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _busy ? null : () => _search(force: _searched),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.accent,
                        disabledBackgroundColor: palette.textDisabled,
                        foregroundColor: palette.accentOn,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_searched ? 'もう一度探す' : '現在地から探す'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: palette.accent)),
                )
              else if (_notice != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Text(
                        _notice!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _search(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.textPrimary,
                          side: BorderSide(color: palette.accent),
                        ),
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              else if (_searched && _suggestions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      '近くのアクティビティが見つかりませんでした',
                      style: TextStyle(
                        color: palette.textDisabled,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                for (final suggestion in _suggestions) ...[
                  _ActivityCard(
                    suggestion: suggestion,
                    pending: ActivityRequestRegistry.instance.hasPendingRequestFor(suggestion.id),
                    onRequest: () => _request(suggestion),
                    palette: palette,
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatefulWidget {
  const _ActivityCard({
    required this.suggestion,
    required this.pending,
    required this.onRequest,
    required this.palette,
  });

  final ActivitySuggestion suggestion;
  final bool pending;
  final VoidCallback onRequest;
  final AppPalette palette;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final suggestion = widget.suggestion;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.isDark ? Colors.white.withValues(alpha: 0.08) : palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder.withValues(alpha: palette.isDark ? 0.35 : 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  suggestion.title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary),
                ),
              ),
            ],
          ),
          if (suggestion.placeName != null) ...[
            const SizedBox(height: 4),
            Text(
              suggestion.placeName!,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ],
          if (_expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.cardBorder.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              suggestion.detail.isEmpty ? '詳細なし' : suggestion.detail,
              style: TextStyle(color: palette.textSecondary),
            ),
            if (suggestion.sourceUrl != null) ...[
              const SizedBox(height: 8),
              Text(
                suggestion.sourceUrl!,
                style: TextStyle(fontSize: 11, color: palette.textDisabled),
              ),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.cardBorder.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: widget.pending ? null : widget.onRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.accentSecondary,
                  disabledBackgroundColor: palette.textDisabled,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: palette.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(widget.pending ? '申請中' : '申請する'),
              ),
            ),
          ],
        ],
      ),
    );

    final decorated = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: palette.isDark
          ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: content)
          : content,
    );

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(12),
      child: decorated,
    );
  }
}
