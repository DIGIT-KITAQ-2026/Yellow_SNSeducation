import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/account_registry.dart';
import '../services/app_session.dart';
import '../services/auth_service.dart';
import '../services/child_registry.dart';
import '../services/group_registry.dart';
import '../services/session_bridge.dart';
import '../widgets/futuristic_background.dart';
import '../widgets/glass_card.dart';

const _cyan = Color(0xFF33F7FF);

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
  }

  @override
  void dispose() {
    ChildRegistry.instance.removeListener(_handleChange);
    AppSession.instance.removeListener(_handleChange);
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

  Future<String?> _showRenameDialog({required String title, required String label, required String initialValue}) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF242428),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: _cyan, width: 2),
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
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
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
                        backgroundColor: _cyan,
                        foregroundColor: const Color(0xFF0B0A24),
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

  Future<void> _renameUser() async {
    final isChild = AppSession.instance.isChild;
    final currentName =
        isChild ? AppSession.instance.childProfile?.name : AppSession.instance.parentName;
    final result = await _showRenameDialog(
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

  Future<void> _renameGroup() async {
    final code = AppSession.instance.groupCode;
    if (code == null) return;
    final result = await _showRenameDialog(
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
        backgroundColor: const Color(0xFF12103A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
                              backgroundColor: const Color(0xFF1B1854),
                              backgroundImage:
                                  avatarBytes != null ? MemoryImage(avatarBytes) : null,
                              child: avatarBytes == null
                                  ? const Icon(Icons.person_outline, size: 40, color: _cyan)
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
                                  color: _cyan,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF12103A), width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 12,
                                  color: Color(0xFF0B0A24),
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
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _renameUser,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          if (AppSession.instance.groupName != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '<${AppSession.instance.groupName}>',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (!isChild) ...[
                              const SizedBox(width: 2),
                              InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _renameGroup,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.5),
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
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'あなたのグループメンバー',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
                            if (i > 0)
                              Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                            _MemberRow(role: memberRoles[i]),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Text(
                      'グループコード',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    if (AppSession.instance.groupCode != null)
                      ...AppSession.instance.groupCode!
                          .split('')
                          .map((digit) => _CodeDot(digit: digit))
                    else
                      ...List.generate(4, (_) => const _CodeDot()),
                  ],
                ),
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

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(role, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF1B1854),
            child: const Icon(Icons.person_outline, size: 16, color: _cyan),
          ),
        ],
      ),
    );
  }
}

class _CodeDot extends StatelessWidget {
  const _CodeDot({this.digit});

  final String? digit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: digit != null ? _cyan.withValues(alpha: 0.12) : null,
        border: Border.all(
          color: digit != null ? _cyan : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: digit != null
          ? Text(digit!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
          : null,
    );
  }
}
