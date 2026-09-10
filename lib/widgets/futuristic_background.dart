import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/theme_controller.dart';

/// アプリ共通の背景。サイバーパンクテーマではネオングリッドの静止画、
/// パステル/白基調テーマでは単純なグラデーションになる。
class FuturisticBackground extends StatelessWidget {
  const FuturisticBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final palette = ThemeController.instance.currentPalette;
        return Container(
          color: palette.scaffoldBackground,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _BackgroundPainter(palette)),
              child,
            ],
          ),
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.palette);

  final AppPalette palette;

  static final List<_Particle> _particles = List.generate(
    36,
    (i) {
      final random = Random(i);
      return _Particle(
        dx: random.nextDouble(),
        dy: random.nextDouble(),
        radius: 0.8 + random.nextDouble() * 1.8,
        brightness: 0.25 + random.nextDouble() * 0.5,
      );
    },
  );

  @override
  void paint(Canvas canvas, Size size) {
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (!palette.showSkyline) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.backgroundGradient,
        ).createShader(skyRect);
      canvas.drawRect(skyRect, paint);
      return;
    }

    final horizonY = size.height * 0.38;

    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: palette.backgroundGradient,
        stops: [0, horizonY / size.height, 1],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.accentSecondary.withValues(alpha: 0.55),
          palette.accentSecondary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, horizonY),
        radius: size.width * 0.55,
      ));
    canvas.drawRect(skyRect, glowPaint);

    for (final p in _particles) {
      final paint = Paint()..color = Colors.white.withValues(alpha: p.brightness);
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * horizonY), p.radius, paint);
    }

    final gridPaint = Paint()
      ..color = palette.accent.withValues(alpha: 0.85)
      ..strokeWidth = 1.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    final vanishingPoint = Offset(size.width / 2, horizonY);
    const laneCount = 7;
    for (var i = 0; i <= laneCount; i++) {
      final xBottom = size.width * (i / laneCount);
      canvas.drawLine(vanishingPoint, Offset(xBottom, size.height), gridPaint);
    }

    // 奥行きを出すための固定の横線(以前は手前に流れるアニメーションだった)。
    const lineCount = 5;
    for (var i = 0; i < lineCount; i++) {
      final progress = (i + 1) / (lineCount + 1);
      final eased = progress * progress;
      final y = horizonY + (size.height - horizonY) * eased;
      final fade = (1 - progress).clamp(0.0, 1.0);
      final linePaint = Paint()
        ..color = palette.accent.withValues(alpha: fade * 0.5)
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final horizonGlowPaint = Paint()
      ..color = palette.accent.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      horizonGlowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) => oldDelegate.palette != palette;
}

class _Particle {
  _Particle({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.brightness,
  });

  final double dx;
  final double dy;
  final double radius;
  final double brightness;
}
