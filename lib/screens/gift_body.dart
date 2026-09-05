import 'package:flutter/material.dart';

import '../models/child_profile.dart';
import '../models/gift_item.dart';
import '../services/achievement_request_registry.dart';
import '../services/app_session.dart';
import '../services/child_notification_registry.dart';
import '../services/child_registry.dart';
import '../services/exchange_request_registry.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/confirm_exchange_dialog.dart';
import '../widgets/futuristic_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/new_gift_dialog.dart';

const _cyan = Color(0xFF33F7FF);
const _magenta = Color(0xFFFF3DAE);

class GiftBody extends StatefulWidget {
  const GiftBody({super.key});

  @override
  State<GiftBody> createState() => _GiftBodyState();
}

class _GiftBodyState extends State<GiftBody> {
  bool _isEditing = false;

  ChildProfile? get _currentProfile => AppSession.instance.isChild
      ? AppSession.instance.childProfile
      : ChildRegistry.instance.selectedInGroup(AppSession.instance.groupCode);

  List<GiftItem> get _items => _currentProfile?.giftItems ?? const [];

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

  Future<void> _openNewGiftDialog() async {
    final profile = _currentProfile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に子供を登録してください')),
      );
      return;
    }
    final result = await showDialog<GiftItem>(
      context: context,
      builder: (_) => const NewGiftDialog(),
    );
    if (result != null) {
      setState(() => profile.giftItems.add(result));
    }
  }

  Future<void> _handleDelete(GiftItem item) async {
    final confirmed = await showConfirmDeleteDialog(context);
    if (confirmed) {
      setState(() => _items.remove(item));
    }
  }

  Future<void> _openEditGiftDialog(GiftItem item) async {
    final result = await showDialog<GiftItem>(
      context: context,
      builder: (_) => NewGiftDialog(initial: item),
    );
    if (result != null) {
      final index = _items.indexOf(item);
      if (index != -1) {
        setState(() => _items[index] = result);
      }
    }
  }

  Future<void> _requestExchange(GiftItem item) async {
    final confirmed = await showConfirmExchangeDialog(context, item.title);
    if (!confirmed || !mounted) return;
    final profile = _currentProfile;
    if (profile == null) return;
    ExchangeRequestRegistry.instance.addRequest(profile, item);
    ChildNotificationRegistry.instance.add(profile, '交換申請を行いました。');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('交換申請を送りました')),
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
              'ご褒美リスト',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'ご褒美はまだありません',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
                children: [
                  for (final item in _items)
                    _GiftItemCard(
                      item: item,
                      isEditing: !isChild && _isEditing,
                      onEdit: () => _openEditGiftDialog(item),
                      onDelete: () => _handleDelete(item),
                      childProfile: isChild ? profile : null,
                      onRequestExchange: () => _requestExchange(item),
                    ),
                ],
              ),
            if (!isChild) ...[
              const SizedBox(height: 16),
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
                        onPressed: _openNewGiftDialog,
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

class _GiftItemCard extends StatelessWidget {
  const _GiftItemCard({
    required this.item,
    required this.isEditing,
    required this.onEdit,
    required this.onDelete,
    required this.childProfile,
    required this.onRequestExchange,
  });

  final GiftItem item;
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ChildProfile? childProfile;
  final VoidCallback onRequestExchange;

  @override
  Widget build(BuildContext context) {
    final pending = ExchangeRequestRegistry.instance.hasPendingRequest(item);
    final cost = int.tryParse(item.points) ?? 0;
    final insufficientPoints = childProfile != null && childProfile!.points < cost;
    return Stack(
      children: [
        GlassCard(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: item.imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          item.imageBytes!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          color: _cyan.withValues(alpha: 0.6),
                          size: 16,
                        ),
                      ),
              ),
              const SizedBox(height: 3),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.points}P',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: _cyan),
              ),
              if (insufficientPoints) ...[
                const SizedBox(height: 2),
                const Text(
                  '交換ポイントが足りません。',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
        if (isEditing) ...[
          Positioned(
            top: 2,
            left: 2,
            child: InkWell(
              onTap: onEdit,
              customBorder: const CircleBorder(),
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.6)),
                ),
                child: const Icon(Icons.edit_outlined, size: 12, color: Colors.lightBlueAccent),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: onDelete,
              customBorder: const CircleBorder(),
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
              ),
            ),
          ),
        ],
        if (childProfile != null)
          Positioned(
            bottom: 2,
            right: 2,
            child: InkWell(
              onTap: (pending || insufficientPoints) ? null : onRequestExchange,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: (pending || insufficientPoints) ? 0.05 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (pending || insufficientPoints)
                        ? Colors.white.withValues(alpha: 0.2)
                        : _magenta.withValues(alpha: 0.7),
                  ),
                ),
                child: Text(
                  pending ? '申請中' : '交換',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: (pending || insufficientPoints)
                        ? Colors.white.withValues(alpha: 0.3)
                        : _magenta,
                  ),
                ),
              ),
            ),
          ),
      ],
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
