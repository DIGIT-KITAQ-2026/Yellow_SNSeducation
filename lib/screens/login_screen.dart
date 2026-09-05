import 'package:flutter/material.dart';

import '../models/account_type.dart';
import '../models/group.dart';
import '../services/account_registry.dart';
import '../services/app_session.dart';
import '../services/child_registry.dart';
import '../services/group_registry.dart';
import '../widgets/account_type_dialog.dart';
import '../widgets/child_signup_dialog.dart';
import '../widgets/parent_signup_dialog.dart';
import 'main_shell.dart';

const _cyan = Color(0xFF33F7FF);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _loginError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _loginError = '入力されていません');
      return;
    }
    final record = AccountRegistry.instance.findByEmail(email);
    if (record == null) {
      setState(() => _loginError = 'このアカウントは登録されていません');
      return;
    }
    if (record.password != password) {
      setState(() => _loginError = 'パスワードが間違っています');
      return;
    }
    setState(() => _loginError = null);
    if (record.role == UserRole.parent) {
      AppSession.instance.loginAsParent();
      if (record.parentName != null) {
        AppSession.instance.setParentName(record.parentName!);
      }
      if (record.parentAvatar != null) {
        AppSession.instance.setParentAvatar(record.parentAvatar!);
      }
      AppSession.instance.setCurrentEmail(email);
    } else {
      AppSession.instance.loginAsChild(record.childProfile!);
    }
    if (record.groupCode != null) {
      AppSession.instance.setGroupCode(record.groupCode!);
      final currentGroupName = GroupRegistry.instance.findByCode(record.groupCode!)?.name;
      final groupName = currentGroupName ?? record.groupName;
      if (groupName != null) {
        AppSession.instance.setGroupName(groupName);
      }
    } else if (record.groupName != null) {
      AppSession.instance.setGroupName(record.groupName!);
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  Future<void> _handleSignUp(BuildContext context) async {
    while (true) {
      final type = await showDialog<AccountType>(
        context: context,
        builder: (_) => const AccountTypeDialog(),
      );
      if (type == null || !context.mounted) return;

      final result = await showDialog<Object?>(
        context: context,
        builder: (_) => type == AccountType.parent
            ? const ParentSignupDialog()
            : const ChildSignupDialog(),
      );
      if (!context.mounted) return;
      if (result == 'back') continue;
      if (result == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
      return;
    }
  }

  void _ensureTestChildren(Group group) {
    if (ChildRegistry.instance.childrenInGroup(group.code).isEmpty) {
      ChildRegistry.instance.addChild('テストこども1', groupCode: group.code);
      ChildRegistry.instance.addChild('テストこども2', groupCode: group.code);
    }
  }

  void _handleTestLoginAsParent() {
    final group = GroupRegistry.instance.ensureTestGroup();
    _ensureTestChildren(group);
    AppSession.instance.loginAsParent();
    AppSession.instance.setParentName('テスト保護者');
    AppSession.instance.setGroupName(group.name);
    AppSession.instance.setGroupCode(group.code);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  void _handleTestLoginAsChild(int index) {
    final group = GroupRegistry.instance.ensureTestGroup();
    _ensureTestChildren(group);
    final profile = ChildRegistry.instance.childrenInGroup(group.code)[index];
    AppSession.instance.loginAsChild(profile);
    AppSession.instance.setGroupName(group.name);
    AppSession.instance.setGroupCode(group.code);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      prefixIcon: Icon(icon, color: _cyan),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: _cyan, width: 2),
      ),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141416), Color(0xFF2A2A2E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 56, color: _cyan),
                  const SizedBox(height: 12),
                  Text(
                    'アカウントログイン',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('メールアドレス', Icons.mail_outline),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('パスワード', Icons.lock_outline),
                  ),
                  if (_loginError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _loginError!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleSignUp(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: _cyan),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('新規'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _cyan,
                            foregroundColor: const Color(0xFF0B0A24),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('ログイン'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'テスト用ログイン(メール・パスワード不要)',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _handleTestLoginAsParent,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('保護者としてテストログイン'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleTestLoginAsChild(0),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('子供1としてテストログイン'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleTestLoginAsChild(1),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('子供2としてテストログイン'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
