import 'package:flutter/material.dart';

import '../models/account_type.dart';

const _cyan = Color(0xFF33F7FF);
const _panelColor = Color(0xFF242428);

class AccountTypeDialog extends StatefulWidget {
  const AccountTypeDialog({super.key});

  @override
  State<AccountTypeDialog> createState() => _AccountTypeDialogState();
}

class _AccountTypeDialogState extends State<AccountTypeDialog> {
  AccountType? _selected;

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
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.7)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Text(
              'タイプを選択',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TypeButton(
                  label: '保護者',
                  icon: Icons.person_outline,
                  selected: _selected == AccountType.parent,
                  onTap: () => setState(() => _selected = AccountType.parent),
                ),
                const SizedBox(width: 16),
                _TypeButton(
                  label: 'お子さま',
                  icon: Icons.child_care_outlined,
                  selected: _selected == AccountType.child,
                  onTap: () => setState(() => _selected = AccountType.child),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: const Color(0xFF0B0A24),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('アカウント作成'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          color: selected ? _cyan.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: selected ? _cyan : Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: selected ? _cyan : Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? _cyan : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
