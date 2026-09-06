import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group.dart';
import '../services/account_registry.dart';
import '../services/app_session.dart';
import '../services/child_registry.dart';
import '../services/group_registry.dart';
import 'credentials_step.dart';

const _cyan = Color(0xFF33F7FF);
const _panelColor = Color(0xFF242428);

class ChildSignupDialog extends StatefulWidget {
  const ChildSignupDialog({super.key});

  @override
  State<ChildSignupDialog> createState() => _ChildSignupDialogState();
}

class _ChildSignupDialogState extends State<ChildSignupDialog> {
  static const _codeLength = 4;

  bool _showCredentials = false;
  bool _codeError = false;
  Group? _matchedGroup;
  final _nameController = TextEditingController();
  final _codeControllers = List.generate(_codeLength, (_) => TextEditingController());
  final _codeFocusNodes = List.generate(_codeLength, (_) => FocusNode());

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final node in _codeFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleContinue() {
    final code = _codeControllers.map((c) => c.text).join();
    final group = GroupRegistry.instance.findByCode(code);
    if (group == null) {
      setState(() => _codeError = true);
      return;
    }
    setState(() {
      _codeError = false;
      _matchedGroup = group;
      _showCredentials = true;
    });
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
                'お子さまアカウント作成',
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
                decoration: InputDecoration(
                  labelText: 'ユーザー名',
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
              const SizedBox(height: 24),
              const Text(
                'グループコード',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _codeLength,
                  (i) => _CodeInputBox(
                    controller: _codeControllers[i],
                    focusNode: _codeFocusNodes[i],
                    onChanged: (value) {
                      if (_codeError) setState(() => _codeError = false);
                      if (value.isNotEmpty && i < _codeLength - 1) {
                        _codeFocusNodes[i + 1].requestFocus();
                      } else if (value.isEmpty && i > 0) {
                        _codeFocusNodes[i - 1].requestFocus();
                      }
                    },
                  ),
                ),
              ),
              if (_codeError) ...[
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'グループコードが一致しません',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _handleContinue,
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
                  final group = _matchedGroup!;
                  if (name.isNotEmpty) {
                    final profile = ChildRegistry.instance.addChild(name, groupCode: group.code);
                    AccountRegistry.instance.registerChild(
                      email: email,
                      password: password,
                      childProfile: profile,
                      groupName: group.name,
                      groupCode: group.code,
                    );
                    AppSession.instance.loginAsChild(profile);
                    AppSession.instance.setGroupName(group.name);
                    AppSession.instance.setGroupCode(group.code);
                  }
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

class _CodeInputBox extends StatelessWidget {
  const _CodeInputBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        decoration: InputDecoration(
          counterText: '',
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
    );
  }
}
