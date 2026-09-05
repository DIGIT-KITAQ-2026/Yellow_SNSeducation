import 'package:flutter/material.dart';

import '../models/quest_item.dart';
import '../utils/numeric_input_formatter.dart';

const _cyan = Color(0xFF33F7FF);
const _panelColor = Color(0xFF1A1740);

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
      TextEditingController(text: widget.initial?.points ?? '');
  late final _detailController =
      TextEditingController(text: widget.initial?.detail ?? '');
  late bool _showDetail = widget.initial?.detail.isNotEmpty ?? false;
  bool _pointsError = false;

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  void _handleComplete() {
    final title = _titleController.text.trim();
    final points = _pointsController.text.trim();
    if (points.isEmpty) {
      setState(() => _pointsError = true);
      return;
    }
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      QuestItem(
        title: title,
        points: points,
        detail: _showDetail ? _detailController.text.trim() : '',
      ),
    );
  }

  InputDecoration _fieldDecoration(String? label, {EdgeInsetsGeometry? contentPadding}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      contentPadding: contentPadding,
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
        side: BorderSide(color: _cyan.withValues(alpha: 0.4)),
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
              widget.initial == null ? '新規作成' : '編集',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration('タイトル'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('設定ポイント', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  height: 40,
                  child: TextField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [NumericInputFormatter()],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (_) {
                      if (_pointsError) setState(() => _pointsError = false);
                    },
                    decoration: _fieldDecoration(null, contentPadding: EdgeInsets.zero),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Ｐ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
            if (_pointsError) ...[
              const SizedBox(height: 4),
              const Text(
                '入力されていません',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('詳細', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
                Switch(
                  value: _showDetail,
                  activeThumbColor: _cyan,
                  onChanged: (value) => setState(() => _showDetail = value),
                ),
              ],
            ),
            if (_showDetail) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _detailController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('詳細を入力（任意）'),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: const Color(0xFF0B0A24),
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
