import 'dart:math';

import 'package:flutter/material.dart';

import '../models/signup_draft.dart';
import '../theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/group_code_boxes.dart';
import '../widgets/primary_button.dart';
import 'credentials_screen.dart';

/// Screen ③ (parent side) of the wireframe (親アカウント作成): group name,
/// plus the group code that gets generated once 決定 is pressed.
///
/// The 決定 button is enabled purely on グループ名 being filled in, matching
/// the wireframe note. The actual random code will be issued by the backend
/// (create_parent_account RPC) later; here a placeholder is generated
/// locally just so the flow can be tried end-to-end.
class ParentSignupScreen extends StatefulWidget {
  const ParentSignupScreen({super.key});

  @override
  State<ParentSignupScreen> createState() => _ParentSignupScreenState();
}

class _ParentSignupScreenState extends State<ParentSignupScreen> {
  final _userNameController = TextEditingController();
  final _groupNameController = TextEditingController();
  String? _generatedCode;

  @override
  void initState() {
    super.initState();
    _groupNameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  void _handleDecide() {
    final random = Random();
    final code = List.generate(4, (_) => random.nextInt(10)).join();
    setState(() => _generatedCode = code);

    final draft = SignupDraft(
      role: AccountRole.parent,
      displayName: _userNameController.text.trim().isEmpty
          ? '保護者'
          : _userNameController.text.trim(),
      groupName: _groupNameController.text.trim(),
      groupCode: code,
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CredentialsScreen(draft: draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDecide = _groupNameController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textSecondary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('親アカウント作成', style: TextStyle(color: AppColors.textPrimary)),
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
                  AppTextField(controller: _userNameController, label: 'ユーザー名'),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _groupNameController,
                    label: 'グループ名',
                    errorText: null,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'グループコード',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  GroupCodeBoxes(code: _generatedCode),
                  const SizedBox(height: 8),
                  const Text(
                    '決定後に発行されます。アカウント情報から確認できます。',
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
