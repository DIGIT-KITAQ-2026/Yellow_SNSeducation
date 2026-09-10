import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.height, this.padding});

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final palette = ThemeController.instance.currentPalette;

        final content = Container(
          height: height,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.isDark ? Colors.white.withValues(alpha: 0.08) : palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: palette.cardBorder.withValues(alpha: palette.isDark ? 0.4 : 1),
            ),
            boxShadow: [
              BoxShadow(
                color: palette.cardShadow.withValues(alpha: palette.isDark ? 0.15 : 0.25),
                blurRadius: palette.isDark ? 16 : 10,
                spreadRadius: palette.isDark ? 1 : 0,
                offset: palette.isDark ? Offset.zero : const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );

        // パステル/白基調では磨りガラス効果は使わず、ソリッドなカードにする。
        if (!palette.isDark) {
          return ClipRRect(borderRadius: BorderRadius.circular(16), child: content);
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: content,
          ),
        );
      },
    );
  }
}
