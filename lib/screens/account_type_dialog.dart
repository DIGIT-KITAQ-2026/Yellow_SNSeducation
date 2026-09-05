import 'package:flutter/material.dart';

import '../models/signup_draft.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';

/// Screen ② of the wireframe (タイプを選択): pick 保護者 or 子ども, then
/// confirm with アカウント作成. Pops with the chosen [AccountRole], or null
/// if closed via the X button.
class AccountTypeDialog extends StatefulWidget {
  const AccountTypeDialog({super.key});

  @override
  State<AccountTypeDialog> createState() => _AccountTypeDialogState();
}

class _AccountTypeDialogState extends State<AccountTypeDialog> {
  AccountRole? _selected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'タイプを選択',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _typeButton(AccountRole.parent, '保護者')),
                const SizedBox(width: 12),
                Expanded(child: _typeButton(AccountRole.child, '子ども')),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'アカウント作成',
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(AccountRole role, String label) {
    final selected = _selected == role;
    return OutlinedButton(
      onPressed: () => setState(() => _selected = role),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.accent.withValues(alpha: 0.15) : null,
        foregroundColor: selected ? AppColors.accent : AppColors.textSecondary,
        side: BorderSide(color: selected ? AppColors.accent : AppColors.fieldBorder),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
