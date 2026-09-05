import 'package:flutter/material.dart';

import '../models/signup_draft.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/auth_errors.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

/// Screen ④ of the wireframe (メールアドレスとパスワードを登録), shared by
/// both the parent and child signup flows: the final step that attaches
/// login credentials to the account details collected in [draft].
///
/// This is where the account is actually created: signUp, then the RPC that
/// creates the profile row (a plain insert is blocked by RLS).
class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({super.key, required this.draft});

  final SignupDraft draft;

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _formError;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDecide() async {
    setState(() {
      _emailError = validateEmail(_emailController.text);
      _passwordError = validatePassword(_passwordController.text);
      _formError = null;
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _busy = true);

    final bool hasSession;
    try {
      hasSession = await AuthService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (error) {
      _fail(error);
      return;
    }

    // The profile RPCs need email confirmations to be off on the Supabase
    // project, otherwise they run as anon and insert a null created_by.
    if (!hasSession) {
      _failWithMessage(
        '確認メールを送信しました。メール内のリンクを開いてから、ログイン画面よりログインしてください',
      );
      return;
    }

    String? groupCode;
    try {
      if (widget.draft.role == AccountRole.parent) {
        groupCode = await AuthService.createParentAccount(
          groupName: widget.draft.groupName!,
          displayName: widget.draft.displayName,
        );
      } else {
        await AuthService.joinGroup(
          code: widget.draft.groupCode!,
          displayName: widget.draft.displayName,
        );
      }
    } catch (error) {
      // The auth user now exists without a profile; drop the session so the
      // app doesn't land in a half-registered state.
      await AuthService.signOut();
      _fail(error);
      return;
    }

    if (!mounted) return;
    if (groupCode != null) await _showGroupCode(groupCode);
    if (!mounted) return;
    // Back to AuthGate, which picks up the new session and profile.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _fail(Object error) => _failWithMessage(authErrorMessage(error));

  void _failWithMessage(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _formError = message;
    });
  }

  Future<void> _showGroupCode(String code) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('グループコード', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 32,
                letterSpacing: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'お子さまのアカウント作成時にこのコードを入力してください。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textSecondary, size: 18),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text('メールアドレスとパスワードを登録', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: _busy ? null : () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  AppTextField(
                    controller: _emailController,
                    label: 'メールアドレス',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _passwordController,
                    label: 'パスワード(6文字以上)',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    errorText: _passwordError,
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _formError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: _busy ? '処理中...' : '決定',
                    onPressed: _busy ? null : _handleDecide,
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
