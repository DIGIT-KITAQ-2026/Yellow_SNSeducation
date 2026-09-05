import 'package:flutter/material.dart';

import '../models/signup_draft.dart';
import '../theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/group_code_boxes.dart';
import '../widgets/primary_button.dart';
import 'credentials_screen.dart';

/// Screen ③ (child side) of the wireframe (子どもアカウント作成): name plus
/// the 4-digit group code shown on the parent's account. 決定 is enabled
/// once both are filled in; whether the code actually matches an existing
/// group is checked against the backend, so for now only the 4-digit
/// format is validated here.
class ChildSignupScreen extends StatefulWidget {
  const ChildSignupScreen({super.key});

  @override
  State<ChildSignupScreen> createState() => _ChildSignupScreenState();
}

class _ChildSignupScreenState extends State<ChildSignupScreen> {
  final _nameController = TextEditingController();
  String _groupCode = '';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleDecide() {
    final draft = SignupDraft(
      role: AccountRole.child,
      displayName: _nameController.text.trim(),
      groupCode: _groupCode,
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CredentialsScreen(draft: draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDecide = _nameController.text.trim().isNotEmpty && _groupCode.length == 4;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textSecondary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('子どもアカウント作成', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
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
                  AppTextField(controller: _nameController, label: 'ユーザー名'),
                  const SizedBox(height: 20),
                  const Text(
                    'グループコード',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  GroupCodeBoxes(
                    editable: true,
                    onChanged: (value) => setState(() => _groupCode = value),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '保護者アカウントに表示されていたのと同じコードを入力する。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: '決定',
                    onPressed: canDecide ? _handleDecide : null,
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
