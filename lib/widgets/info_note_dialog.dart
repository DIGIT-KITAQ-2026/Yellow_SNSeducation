import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';

Future<void> showInfoNoteDialog(BuildContext context, String message, {String title = '注意点'}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    ),
  );
}

class InfoButton extends StatelessWidget {
  const InfoButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeController.instance.currentPalette;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.textSecondary),
        ),
        child: Text(
          '？',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: palette.textSecondary,
          ),
        ),
      ),
    );
  }
}
