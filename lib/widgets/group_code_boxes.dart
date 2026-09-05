import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Four boxes for a 4-digit group code, matching the "□ □ □ □" sketch.
///
/// In editable mode each box accepts one digit and auto-advances focus,
/// used by the child signup screen. In read-only mode it just displays
/// [code] (or a placeholder dash while no code has been generated yet),
/// used by the parent signup screen.
class GroupCodeBoxes extends StatefulWidget {
  const GroupCodeBoxes({
    super.key,
    this.editable = false,
    this.code,
    this.onChanged,
  });

  final bool editable;
  final String? code;
  final ValueChanged<String>? onChanged;

  @override
  State<GroupCodeBoxes> createState() => _GroupCodeBoxesState();
}

class _GroupCodeBoxesState extends State<GroupCodeBoxes> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _emitChange() {
    widget.onChanged?.call(_controllers.map((c) => c.text).join());
  }

  @override
  Widget build(BuildContext context) {
    final digits = List.generate(4, (i) {
      if (!widget.editable) {
        return (widget.code != null && widget.code!.length == 4) ? widget.code![i] : '-';
      }
      return null;
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SizedBox(
            width: 52,
            height: 56,
            child: widget.editable
                ? TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 20),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.fieldBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.fieldBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && i < 3) {
                        _focusNodes[i + 1].requestFocus();
                      } else if (value.isEmpty && i > 0) {
                        _focusNodes[i - 1].requestFocus();
                      }
                      _emitChange();
                    },
                  )
                : Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.fieldBorder),
                    ),
                    child: Text(
                      digits[i]!,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 20),
                    ),
                  ),
          ),
        );
      }),
    );
  }
}
