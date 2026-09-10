import 'package:flutter/material.dart';

import '../screens/account_info_screen.dart';
import '../services/app_session.dart';
import '../services/child_registry.dart';
import '../theme/theme_controller.dart';
import 'info_note_dialog.dart';
import 'notification_bell.dart';

class AccountBar extends StatefulWidget {
  const AccountBar({super.key});

  @override
  State<AccountBar> createState() => _AccountBarState();
}

class _AccountBarState extends State<AccountBar> {
  @override
  void initState() {
    super.initState();
    ChildRegistry.instance.addListener(_handleRegistryChange);
    AppSession.instance.addListener(_handleRegistryChange);
    ThemeController.instance.addListener(_handleRegistryChange);
  }

  @override
  void dispose() {
    ChildRegistry.instance.removeListener(_handleRegistryChange);
    AppSession.instance.removeListener(_handleRegistryChange);
    ThemeController.instance.removeListener(_handleRegistryChange);
    super.dispose();
  }

  void _handleRegistryChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeController.instance.currentPalette;
    final isChild = AppSession.instance.isChild;
    final children = ChildRegistry.instance.childrenInGroup(AppSession.instance.groupCode);
    final selected = ChildRegistry.instance.selectedInGroup(AppSession.instance.groupCode);
    final displayName = isChild
        ? AppSession.instance.childProfile?.name
        : AppSession.instance.parentName;
    final avatarBytes = isChild
        ? AppSession.instance.childProfile?.avatarBytes
        : AppSession.instance.parentAvatar;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.navBackground,
        border: Border(bottom: BorderSide(color: palette.navBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: palette.isDark
                ? palette.navBorder.withValues(alpha: 0.25)
                : palette.cardShadow.withValues(alpha: 0.3),
            blurRadius: palette.isDark ? 12 : 8,
            spreadRadius: palette.isDark ? -2 : 0,
            offset: palette.isDark ? Offset.zero : const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: palette.surfaceAlt,
                  backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes) : null,
                  child: avatarBytes == null
                      ? Icon(Icons.person_outline, size: 20, color: palette.accent)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                displayName ?? 'ユーザー名なし',
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
              ),
              if (AppSession.instance.groupName != null) ...[
                const SizedBox(width: 6),
                Text(
                  '<${AppSession.instance.groupName}>',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
              const Spacer(),
              const NotificationBell(),
              if (!isChild) ...[
                const SizedBox(width: 4),
                InfoButton(
                  onTap: () => showInfoNoteDialog(
                    context,
                    '達成の認証スタンプは、保護者が「完了」ボタンを押すまで確定せず、'
                    '押すまでは所持ポイントに加算されません。\n\n'
                    '交換の認証スタンプも同様に、「完了」を押すまでは所持ポイントから'
                    '差し引かれません。',
                  ),
                ),
                const SizedBox(width: 8),
                _ChildSwitcher(
                  children: children.map((child) => child.name).toList(),
                  selected: selected?.name,
                  onChanged: (value) => ChildRegistry.instance.selectChild(value),
                ),
              ],
            ],
          ),
          if (!isChild && selected != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Text(
                '表示中:${selected.name}',
                style: TextStyle(fontSize: 12, color: palette.textDisabled),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChildSwitcher extends StatelessWidget {
  const _ChildSwitcher({
    required this.children,
    required this.selected,
    required this.onChanged,
  });

  final List<String> children;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeController.instance.currentPalette;
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (context) => children.isEmpty
          ? [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  '登録された子供がいません',
                  style: TextStyle(color: palette.textDisabled),
                ),
              ),
            ]
          : children
              .map((name) => PopupMenuItem<String>(value: name, child: Text(name)))
              .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: palette.isDark ? Colors.white.withValues(alpha: 0.08) : palette.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.cardBorder.withValues(alpha: palette.isDark ? 0.5 : 1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected ?? '子供を選択',
              style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary),
            ),
            Icon(Icons.arrow_drop_down, color: palette.accent),
          ],
        ),
      ),
    );
  }
}
