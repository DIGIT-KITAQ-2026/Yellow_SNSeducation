import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/account_registry.dart';
import '../services/app_session.dart';
import '../services/auth_service.dart';
import '../services/child_registry.dart';
import '../services/group_registry.dart';
import '../services/session_bridge.dart';
import '../theme/app_palette.dart';
import '../theme/theme_controller.dart';
import '../widgets/futuristic_background.dart';
import '../widgets/glass_card.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  @override
  void initState() {
    super.initState();
    ChildRegistry.instance.addListener(_handleChange);
    AppSession.instance.addListener(_handleChange);
    ThemeController.instance.addListener(_handleChange);
  }

  @override
  void dispose() {
    ChildRegistry.instance.removeListener(_handleChange);
    AppSession.instance.removeListener(_handleChange);
    ThemeController.instance.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() => setState(() {});

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (AppSession.instance.isChild) {
      AppSession.instance.setChildAvatar(bytes);
    } else {
      AppSession.instance.setParentAvatar(bytes);
      final email = AppSession.instance.currentEmail;
      if (email != null) {
        AccountRegistry.instance.updateParentAvatar(email, bytes);
      }
    }
  }

  Future<String?> _showRenameDialog({
    required AppPalette palette,
    required String title,
    required String label,
    required String initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: palette.dialogBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: palette.cardBorder.withValues(alpha: palette.isDark ? 0.3 : 1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: palette.textPrimary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(color: palette.textSecondary),
                  filled: true,
                  fillColor: palette.inputFill,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: palette.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: palette.accent, width: 2),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                        side: BorderSide(color: palette.inputBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('キャンセル'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.accent,
                        foregroundColor: palette.accentOn,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameUser(AppPalette palette) async {
    final isChild = AppSession.instance.isChild;
    final currentName =
        isChild ? AppSession.instance.childProfile?.name : AppSession.instance.parentName;
    final result = await _showRenameDialog(
      palette: palette,
      title: 'ユーザー名を変更',
      label: 'ユーザー名',
      initialValue: currentName ?? '',
    );
    if (result == null || result.isEmpty) return;
    if (isChild) {
      AppSession.instance.renameChild(result);
    } else {
      AppSession.instance.setParentName(result);
      final email = AppSession.instance.currentEmail;
      if (email != null) {
        AccountRegistry.instance.updateParentName(email, result);
      }
    }
  }

  Future<void> _renameGroup(AppPalette palette) async {
    final code = AppSession.instance.groupCode;
    if (code == null) return;
    final result = await _showRenameDialog(
      palette: palette,
      title: 'グループ名を変更',
      label: 'グループ名',
      initialValue: AppSession.instance.groupName ?? '',
    );
    if (result == null || result.isEmpty) return;
    GroupRegistry.instance.renameGroup(code, result);
    AppSession.instance.setGroupName(result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeController.instance.currentPalette;
    final isChild = AppSession.instance.isChild;
    final myChildName = AppSession.instance.childProfile?.name;
    final displayName = isChild ? myChildName : AppSession.instance.parentName;
    final avatarBytes = isChild
        ? AppSession.instance.childProfile?.avatarBytes
        : AppSession.instance.parentAvatar;
    final memberRoles = [
      isChild ? '保護者' : '保護者(自分)',
      ...ChildRegistry.instance.childrenInGroup(AppSession.instance.groupCode).map(
        (child) => isChild && child.name == myChildName
            ? '${child.name}(自分)'
            : child.name,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.navBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      body: FuturisticBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: palette.surfaceAlt,
                              backgroundImage:
                                  avatarBytes != null ? MemoryImage(avatarBytes) : null,
                              child: avatarBytes == null
                                  ? Icon(Icons.person_outline, size: 40, color: palette.accent)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: palette.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: palette.navBackground, width: 2),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 12,
                                  color: palette.accentOn,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName ?? 'ユーザー名なし',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _renameUser(palette),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                          if (AppSession.instance.groupName != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '<${AppSession.instance.groupName}>',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (!isChild) ...[
                              const SizedBox(width: 2),
                              InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _renameGroup(palette),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'メールアドレス未設定',
                        style: TextStyle(color: palette.textDisabled, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'あなたのグループメンバー',
                  style: TextStyle(fontWeight: FontWeight.bold, color: palette.textPrimary),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IntrinsicWidth(
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < memberRoles.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: palette.cardBorder.withValues(alpha: 0.3)),
                            _MemberRow(role: memberRoles[i], palette: palette),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Text(
                      'グループコード',
                      style: TextStyle(fontWeight: FontWeight.bold, color: palette.textPrimary),
                    ),
                    const SizedBox(width: 16),
                    if (AppSession.instance.groupCode != null)
                      ...AppSession.instance.groupCode!
                          .split('')
                          .map((digit) => _CodeDot(digit: digit, palette: palette))
                    else
                      ...List.generate(4, (_) => _CodeDot(palette: palette)),
                  ],
                ),
                if (isChild) ...[
                  const SizedBox(height: 32),
                  Text(
                    '画面のテーマ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: palette.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  _ThemePicker(palette: palette),
                ],
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService.signOut();
                      SessionBridge.clear();
                      if (!context.mounted) return;
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('ログアウト'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final child = AppSession.instance.childProfile;
    if (child == null) return const SizedBox.shrink();
    final current = ThemeController.instance.kindFor(child);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ThemeOptionCard(
          label: 'ナチュラル',
          description: 'ゆったり、安心',
          icon: Icons.eco_rounded,
          previewColor: AppPalette.natural.accent,
          previewBackground: AppPalette.natural.scaffoldBackground,
          selected: current == AppThemeKind.natural,
          onTap: () => ThemeController.instance.setKind(child, AppThemeKind.natural),
          palette: palette,
        ),
        const SizedBox(height: 12),
        _ThemeOptionCard(
          label: 'パステル',
          description: '淡いピンク系UI',
          icon: Icons.favorite_rounded,
          previewColor: AppPalette.pastel.accent,
          previewBackground: AppPalette.pastel.scaffoldBackground,
          selected: current == AppThemeKind.pastel,
          onTap: () => ThemeController.instance.setKind(child, AppThemeKind.pastel),
          palette: palette,
        ),
        const SizedBox(height: 12),
        _ThemeOptionCard(
          label: 'サイバー',
          description: '今のネオン系UI',
          icon: Icons.bolt_rounded,
          previewColor: AppPalette.cyberpunk.accent,
          previewBackground: AppPalette.cyberpunk.scaffoldBackground,
          selected: current == AppThemeKind.cyberpunk,
          onTap: () => ThemeController.instance.setKind(child, AppThemeKind.cyberpunk),
          palette: palette,
        ),
        const SizedBox(height: 12),
        _ThemeOptionCard(
          label: 'オーシャン',
          description: 'すっきり爽やか',
          icon: Icons.water_drop_rounded,
          previewColor: AppPalette.ocean.accent,
          previewBackground: AppPalette.ocean.scaffoldBackground,
          selected: current == AppThemeKind.ocean,
          onTap: () => ThemeController.instance.setKind(child, AppThemeKind.ocean),
          palette: palette,
        ),
      ],
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.previewColor,
    required this.previewBackground,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color previewColor;
  final Color previewBackground;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: previewBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? previewColor : palette.cardBorder.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: previewColor.withValues(alpha: 0.4), blurRadius: 10)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: previewColor, size: 20),
                const Spacer(),
                if (selected) Icon(Icons.check_circle, color: previewColor, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: previewBackground.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: previewBackground.computeLuminance() > 0.5
                    ? Colors.black54
                    : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.role, required this.palette});

  final String role;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(role, style: TextStyle(fontWeight: FontWeight.bold, color: palette.textPrimary)),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 14,
            backgroundColor: palette.surfaceAlt,
            child: Icon(Icons.person_outline, size: 16, color: palette.accent),
          ),
        ],
      ),
    );
  }
}

class _CodeDot extends StatelessWidget {
  const _CodeDot({this.digit, required this.palette});

  final String? digit;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: digit != null ? palette.accent.withValues(alpha: 0.12) : null,
        border: Border.all(
          color: digit != null ? palette.accent : palette.cardBorder.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: digit != null
          ? Text(digit!, style: TextStyle(fontWeight: FontWeight.bold, color: palette.textPrimary))
          : null,
    );
  }
}
