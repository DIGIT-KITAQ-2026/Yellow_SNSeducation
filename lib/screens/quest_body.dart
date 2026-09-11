import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/child_profile.dart';
import '../models/quest_item.dart';
import '../services/achievement_request_registry.dart';
import '../services/activity_request_registry.dart';
import '../services/app_session.dart';
import '../services/child_notification_registry.dart';
import '../services/child_registry.dart';
import '../services/exchange_request_registry.dart';
import '../services/quest_service.dart';
import '../theme/app_palette.dart';
import '../theme/theme_controller.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/futuristic_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/new_task_dialog.dart';

class QuestBody extends StatefulWidget {
  const QuestBody({super.key});

  @override
  State<QuestBody> createState() => _QuestBodyState();
}

class _QuestBodyState extends State<QuestBody> {
  bool _isEditing = false;
  bool _busy = false;

  ChildProfile? get _currentProfile => AppSession.instance.isChild
      ? AppSession.instance.childProfile
      : ChildRegistry.instance.selectedInGroup(AppSession.instance.groupCode);

  List<QuestItem> get _items => _currentProfile?.questItems ?? const [];

  @override
  void initState() {
    super.initState();
    ChildRegistry.instance.addListener(_handleRegistryChange);
    AppSession.instance.addListener(_handleRegistryChange);
    AchievementRequestRegistry.instance.addListener(_handleRegistryChange);
    ExchangeRequestRegistry.instance.addListener(_handleRegistryChange);
    ActivityRequestRegistry.instance.addListener(_handleRegistryChange);
    ThemeController.instance.addListener(_handleRegistryChange);
  }

  @override
  void dispose() {
    ChildRegistry.instance.removeListener(_handleRegistryChange);
    AppSession.instance.removeListener(_handleRegistryChange);
    AchievementRequestRegistry.instance.removeListener(_handleRegistryChange);
    ExchangeRequestRegistry.instance.removeListener(_handleRegistryChange);
    ActivityRequestRegistry.instance.removeListener(_handleRegistryChange);
    ThemeController.instance.removeListener(_handleRegistryChange);
    super.dispose();
  }

  void _handleRegistryChange() => setState(() {});

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openNewTaskDialog() async {
    if (_busy) return;
    final profile = _currentProfile;
    final groupId = AppSession.instance.groupId;
    if (profile?.id == null || groupId == null) {
      _showError('先に子供を登録してください');
      return;
    }
    final result = await showDialog<QuestItem>(
      context: context,
      builder: (_) => const NewTaskDialog(),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      final created = await QuestService.createTask(
        groupId: groupId,
        childId: profile!.id!,
        title: result.title,
        points: result.points,
        detail: result.detail,
      );
      if (!mounted) return;
      setState(() => profile.questItems.add(created));
    } catch (_) {
      _showError('保存に失敗しました。もう一度お試しください');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete(QuestItem item) async {
    if (_busy) return;
    final confirmed = await showConfirmDeleteDialog(context);
    if (!confirmed || item.id == null) return;

    setState(() => _busy = true);
    try {
      await QuestService.deleteTask(item.id!);
      if (!mounted) return;
      setState(() => _items.remove(item));
    } catch (_) {
      _showError('削除に失敗しました。もう一度お試しください');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditTaskDialog(QuestItem item) async {
    if (_busy) return;
    final result = await showDialog<QuestItem>(
      context: context,
      builder: (_) => NewTaskDialog(initial: item),
    );
    if (result == null) return;
    final index = _items.indexOf(item);
    if (index == -1 || result.id == null) return;

    setState(() => _busy = true);
    try {
      final updated = await QuestService.updateTask(result);
      if (!mounted) return;
      setState(() => _items[index] = updated);
    } catch (_) {
      _showError('更新に失敗しました。もう一度お試しください');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestAchievement(QuestItem item) async {
    if (_busy) return;
    final profile = _currentProfile;
    if (profile == null) return;

    setState(() => _busy = true);
    try {
      await AchievementRequestRegistry.instance.addRequest(profile, item);
      if (!mounted) return;
      ChildNotificationRegistry.instance.add(profile, '達成申請を行いました。');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('達成申請を送りました')),
      );
    } catch (_) {
      _showError('送信に失敗しました。もう一度お試しください');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeController.instance.currentPalette;
    final isChild = AppSession.instance.isChild;
    final profile = _currentProfile;
    return FuturisticBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PointsCard(points: profile?.points ?? 0, palette: palette),
            const SizedBox(height: 16),
            Text(
              'やることリスト',
              style: TextStyle(fontWeight: FontWeight.bold, color: palette.textPrimary),
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'やることリストはありません',
                    style: TextStyle(
                      color: palette.textDisabled,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            for (final item in _items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _QuestItemBar(
                      item: item,
                      childProfile: isChild ? profile : null,
                      onRequestAchievement: () => _requestAchievement(item),
                      palette: palette,
                    ),
                  ),
                  if (!isChild && _isEditing) ...[
                    const SizedBox(width: 8),
                    _ItemEditButton(onTap: () => _openEditTaskDialog(item), palette: palette),
                    const SizedBox(width: 8),
                    _DeleteButton(onTap: () => _confirmDelete(item), palette: palette),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (!isChild) ...[
              Align(
                alignment: Alignment.centerRight,
                child: _EditButton(
                  onTap: () => setState(() => _isEditing = !_isEditing),
                  palette: palette,
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _openNewTaskDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.textPrimary,
                          side: BorderSide(color: palette.accent),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('新規作成'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _isEditing = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: palette.accentOn,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('完了'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap, required this.palette});

  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.accentSecondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.accentSecondary.withValues(alpha: 0.6)),
        ),
        child: Icon(Icons.edit_outlined, size: 20, color: palette.accentSecondary),
      ),
    );
  }
}

class _ItemEditButton extends StatelessWidget {
  const _ItemEditButton({required this.onTap, required this.palette});

  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.isDark ? Colors.white.withValues(alpha: 0.08) : palette.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.6)),
        ),
        child: const Icon(Icons.edit_outlined, size: 16, color: Colors.lightBlueAccent),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap, required this.palette});

  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.isDark ? Colors.white.withValues(alpha: 0.08) : palette.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
        ),
        child: const Icon(Icons.close, size: 18, color: Colors.redAccent),
      ),
    );
  }
}

class _QuestItemBar extends StatefulWidget {
  const _QuestItemBar({
    required this.item,
    required this.childProfile,
    required this.onRequestAchievement,
    required this.palette,
  });

  final QuestItem item;
  final ChildProfile? childProfile;
  final VoidCallback onRequestAchievement;
  final AppPalette palette;

  @override
  State<_QuestItemBar> createState() => _QuestItemBarState();
}

class _QuestItemBarState extends State<_QuestItemBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final pending = AchievementRequestRegistry.instance.hasPendingRequest(widget.item);

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
                  widget.item.title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary),
                ),
              ),
              Text(
                '${widget.item.points}P',
                style: TextStyle(fontWeight: FontWeight.bold, color: palette.accent),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.cardBorder.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              widget.item.detail.isEmpty ? '詳細なし' : widget.item.detail,
              style: TextStyle(color: palette.textSecondary),
            ),
            if (widget.childProfile != null) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: palette.cardBorder.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: pending ? null : widget.onRequestAchievement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accent,
                    disabledBackgroundColor: palette.textDisabled,
                    foregroundColor: palette.accentOn,
                    disabledForegroundColor: palette.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(pending ? '申請中' : '達成'),
                ),
              ),
            ],
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

class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.points, required this.palette});

  final int points;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Text(
            '所持ポイント',
            style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary),
          ),
          const Spacer(),
          Container(
            width: 56,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: palette.accent, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$points',
              style: TextStyle(fontWeight: FontWeight.bold, color: palette.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Text('Point', style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary)),
        ],
      ),
    );
  }
}
