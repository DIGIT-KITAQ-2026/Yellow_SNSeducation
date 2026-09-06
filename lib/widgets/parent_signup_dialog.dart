import 'package:flutter/material.dart';

import '../services/account_registry.dart';
import '../services/app_session.dart';
import '../services/group_registry.dart';
import 'credentials_step.dart';

const _cyan = Color(0xFF33F7FF);
const _panelColor = Color(0xFF242428);

class ParentSignupDialog extends StatefulWidget {
  const ParentSignupDialog({super.key});

  @override
  State<ParentSignupDialog> createState() => _ParentSignupDialogState();
}

class _ParentSignupDialogState extends State<ParentSignupDialog> {
  late final _group = GroupRegistry.instance.createGroup('');
  String get _groupCode => _group.code;
  final _nameController = TextEditingController();
  final _groupNameController = TextEditingController();
  bool _showCredentials = false;

  @override
  void dispose() {
    _nameController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _panelColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (!_showCredentials)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop('back'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.7)),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('戻る'),
                  ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.7)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (!_showCredentials) ...[
              Text(
                '保護者アカウント作成',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('ユーザー名'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _groupNameController,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('グループ名を入力'),
              ),
              const SizedBox(height: 24),
              const Text(
                'グループコード',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _groupCode
                    .split('')
                    .map((digit) => _CodeBox(digit))
                    .toList(),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: () {},
                  style: TextButton.styleFrom(foregroundColor: _cyan),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('コピー'),
                ),
              ),
              Text(
                'このコードはお子さまアカウントの参加時に使用します',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => setState(() => _showCredentials = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cyan,
                  foregroundColor: const Color(0xFF0B0A24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('決定'),
              ),
            ] else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showCredentials = false),
                  style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.7)),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('戻る'),
                ),
              ),
              Text(
                'メールアドレスとパスワードを登録',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),
              CredentialsStep(
                onSubmit: (email, password) {
                  final name = _nameController.text.trim();
                  final groupName = _groupNameController.text.trim();
                  GroupRegistry.instance.renameGroup(_group.code, groupName);
                  AccountRegistry.instance.registerParent(
                    email: email,
                    password: password,
                    parentName: name.isEmpty ? null : name,
                    groupName: groupName.isEmpty ? null : groupName,
                    groupCode: _groupCode,
                  );
                  AppSession.instance.loginAsParent();
                  if (name.isNotEmpty) {
                    AppSession.instance.setParentName(name);
                  }
                  if (groupName.isNotEmpty) {
                    AppSession.instance.setGroupName(groupName);
                  }
                  AppSession.instance.setGroupCode(_groupCode);
                  AppSession.instance.setCurrentEmail(email);
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox(this.digit);

  final String digit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 40,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _cyan.withValues(alpha: 0.12),
        border: Border.all(color: _cyan.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        digit,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}
