import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/child_profile.dart';
import '../models/quest_item.dart';
import '../services/achievement_request_registry.dart';
import '../services/app_session.dart';
import '../services/child_notification_registry.dart';
import '../services/child_registry.dart';
import '../services/exchange_request_registry.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/futuristic_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/new_task_dialog.dart';

const _cyan = Color(0xFF33F7FF);
const _magenta = Color(0xFFFF3DAE);

class QuestBody extends StatefulWidget {
  const QuestBody({super.key});

  @override
  State<QuestBody> createState() => _QuestBodyState();
}

class _QuestBodyState extends State<QuestBody> {
  bool _isEditing = false;

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
  }

  @override
  void dispose() {
    ChildRegistry.instance.removeListener(_handleRegistryChange);
    AppSession.instance.removeListener(_handleRegistryChange);
    AchievementRequestRegistry.instance.removeListener(_handleRegistryChange);
    ExchangeRequestRegistry.instance.removeListener(_handleRegistryChange);
    super.dispose();
  }

  void _handleRegistryChange() => setState(() {});

  Future<void> _openNewTaskDialog() async {
    final profile = _currentProfile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に子供を登録してください')),
      );
      return;
    }
    final result = await showDialog<QuestItem>(
      context: context,
      builder: (_) => const NewTaskDialog(),
    );
    if (result != null) {
      setState(() => profile.questItems.add(result));
    }
  }

  Future<void> _confirmDelete(QuestItem item) async {
    final confirmed = await showConfirmDeleteDialog(context);
    if (confirmed) {
      setState(() => _items.remove(item));
    }
  }

  Future<void> _openEditTaskDialog(QuestItem item) async {
    final result = await showDialog<QuestItem>(
      context: context,
      builder: (_) => NewTaskDialog(initial: item),
    );
    if (result != null) {
      final index = _items.indexOf(item);
      if (index != -1) {
        setState(() => _items[index] = result);
      }
    }
  }

  void _requestAchievement(QuestItem item) {
    final profile = _currentProfile;
    if (profile == null) return;
    AchievementRequestRegistry.instance.addRequest(profile, item);
    ChildNotificationRegistry.instance.add(profile, '達成申請を行いました。');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('達成申請を送りました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isChild = AppSession.instance.isChild;
    final profile = _currentProfile;
    return FuturisticBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PointsCard(points: profile?.points ?? 0),
            const SizedBox(height: 16),
            const Text(
              'やることリスト',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'やることリストはありません',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
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
                    ),
                  ),
                  if (!isChild && _isEditing) ...[
                    const SizedBox(width: 8),
                    _ItemEditButton(onTap: () => _openEditTaskDialog(item)),
                    const SizedBox(width: 8),
                    _DeleteButton(onTap: () => _confirmDelete(item)),
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
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: _cyan),
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
                          backgroundColor: _cyan,
                          foregroundColor: const Color(0xFF0B0A24),
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
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

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
          color: _magenta.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _magenta.withValues(alpha: 0.6)),
        ),
        child: const Icon(Icons.edit_outlined, size: 20, color: _magenta),
      ),
    );
  }
}

class _ItemEditButton extends StatelessWidget {
  const _ItemEditButton({required this.onTap});

  final VoidCallback onTap;

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
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.6)),
        ),
        child: const Icon(Icons.edit_outlined, size: 16, color: Colors.lightBlueAccent),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback onTap;

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
          color: Colors.white.withValues(alpha: 0.08),
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
  });

  final QuestItem item;
  final ChildProfile? childProfile;
  final VoidCallback onRequestAchievement;

  @override
  State<_QuestItemBar> createState() => _QuestItemBarState();
}

class _QuestItemBarState extends State<_QuestItemBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final pending = AchievementRequestRegistry.instance.hasPendingRequest(widget.item);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cyan.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                    Text(
                      '${widget.item.points}P',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _cyan),
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  Text(
                    widget.item.detail.isEmpty ? '詳細なし' : widget.item.detail,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  if (widget.childProfile != null) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: pending ? null : widget.onRequestAchievement,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cyan,
                          disabledBackgroundColor: Colors.white.withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFF0B0A24),
                          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
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
          ),
        ),
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          const Text(
            '所持ポイント',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const Spacer(),
          Container(
            width: 56,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: _cyan, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$points',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          const Text('Point', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}
