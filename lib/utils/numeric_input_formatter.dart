import 'package:flutter/services.dart';

/// Keeps only digit characters, converting full-width digits (０-９) to
/// half-width (0-9) so the stored text is always parseable with [int.tryParse].
class NumericInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    for (final rune in newValue.text.runes) {
      if (rune >= 0xFF10 && rune <= 0xFF19) {
        buffer.writeCharCode(rune - 0xFF10 + 0x30);
      } else if (rune >= 0x30 && rune <= 0x39) {
        buffer.writeCharCode(rune);
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
