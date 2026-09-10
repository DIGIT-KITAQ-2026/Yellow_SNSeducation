import 'package:flutter/material.dart';

import '../models/quest_item.dart';
import '../theme/app_palette.dart';
import '../theme/theme_controller.dart';
import '../utils/numeric_input_formatter.dart';

class NewTaskDialog extends StatefulWidget {
  const NewTaskDialog({super.key, this.initial});

  final QuestItem? initial;

  @override
  State<NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends State<NewTaskDialog> {
  late final _titleController =
      TextEditingController(text: widget.initial?.title ?? '');
  late final _pointsController =
      TextEditingController(text: widget.initial?.points.toString() ?? '');
  late final _detailController =
      TextEditingController(text: widget.initial?.detail ?? '');
  late bool _showDetail = widget.initial?.detail.isNotEmpty ?? false;
  bool _pointsError = false;
  String _pointsErrorText = '入力されていません';

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  void _handleComplete() {
    final title = _titleController.text.trim();
    final pointsText = _pointsController.text.trim();
    if (pointsText.isEmpty) {
      setState(() {
        _pointsError = true;
        _pointsErrorText = '入力されていません';
      });
      return;
    }
    final points = int.tryParse(pointsText);
    // DBの制約(tasks.points > 0)に合わせて、0以下は弾く。
    if (points == null || points <= 0) {
      setState(() {
        _pointsError = true;
        _pointsErrorText = '1以上を入力してください';
      });
      return;
    }
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      QuestItem(
        id: widget.initial?.id,
        title: title,
        points: points,
        detail: _showDetail ? _detailController.text.trim() : '',
      ),
    );
  }

  InputDecoration _fieldDecoration(
    AppPalette palette,
    String? label, {
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.textSecondary),
      contentPadding: contentPadding,
      filled: true,
      fillColor: palette.inputFill,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: palette.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: palette.accent, width: 2),
      ),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeController.instance.currentPalette;
    return Dialog(
      backgroundColor: palette.dialogBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.cardBorder.withValues(alpha: palette.isDark ? 0.4 : 1)),
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
                icon: Icon(Icons.close, color: palette.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Text(
              widget.initial == null ? '新規作成' : '編集',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold, color: palette.textPrimary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              style: TextStyle(color: palette.textPrimary),
              decoration: _fieldDecoration(palette, 'タイトル'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('設定ポイント', style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  height: 40,
                  child: TextField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [NumericInputFormatter()],
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textPrimary),
                    onChanged: (_) {
                      if (_pointsError) setState(() => _pointsError = false);
                    },
                    decoration: _fieldDecoration(palette, null, contentPadding: EdgeInsets.zero),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Ｐ', style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary)),
              ],
            ),
            if (_pointsError) ...[
              const SizedBox(height: 4),
              Text(
                _pointsErrorText,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('詳細', style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary)),
                ),
                Switch(
                  value: _showDetail,
                  activeThumbColor: palette.accent,
                  onChanged: (value) => setState(() => _showDetail = value),
                ),
              ],
            ),
            if (_showDetail) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _detailController,
                maxLines: 3,
                style: TextStyle(color: palette.textPrimary),
                decoration: _fieldDecoration(palette, '詳細を入力（任意）'),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.accentOn,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('完了'),
            ),
          ],
        ),
      ),
    );
  }
}
