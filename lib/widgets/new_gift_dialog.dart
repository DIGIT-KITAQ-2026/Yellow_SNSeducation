import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/gift_item.dart';
import '../utils/numeric_input_formatter.dart';

const _cyan = Color(0xFF33F7FF);
const _panelColor = Color(0xFF1A1740);

class NewGiftDialog extends StatefulWidget {
  const NewGiftDialog({super.key, this.initial});

  final GiftItem? initial;

  @override
  State<NewGiftDialog> createState() => _NewGiftDialogState();
}

class _NewGiftDialogState extends State<NewGiftDialog> {
  late final _titleController =
      TextEditingController(text: widget.initial?.title ?? '');
  late final _pointsController =
      TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.points}');
  late Uint8List? _imageBytes = widget.initial?.imageBytes;
  late bool _alwaysVisible = widget.initial?.alwaysVisible ?? false;
  bool _titleError = false;
  bool _pointsError = false;

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    final points = int.tryParse(_pointsController.text.trim()) ?? 0;
    setState(() {
      _titleError = title.isEmpty;
      // rewards.cost_points > 0 の制約に合わせる。
      _pointsError = points <= 0;
    });
    if (_titleError || _pointsError) return;
    Navigator.of(context).pop(
      GiftItem(
        id: widget.initial?.id,
        title: title,
        points: points,
        alwaysVisible: _alwaysVisible,
        imagePath: widget.initial?.imagePath,
        imageBytes: _imageBytes,
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
            if (_imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _imageBytes!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _pickImage,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.photo_outlined, color: _cyan),
              label: Text(_imageBytes == null ? '写真を選択(任意)' : '写真を変更'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) {
                if (_titleError) setState(() => _titleError = false);
              },
              decoration: _fieldDecoration('商品名'),
            ),
            if (_titleError) ...[
              const SizedBox(height: 4),
              const Text(
                '入力されていません',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
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
                '1以上の数字を入力してください',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            InkWell(
              onTap: () => setState(() => _alwaysVisible = !_alwaysVisible),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Checkbox(
                    value: _alwaysVisible,
                    activeColor: _cyan,
                    onChanged: (value) => setState(() => _alwaysVisible = value ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      '常に表示する(承認後もリストに残し、繰り返し交換できるようにする)',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: const Color(0xFF0B0A24),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
