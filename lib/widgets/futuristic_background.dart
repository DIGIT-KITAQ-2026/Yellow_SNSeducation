import 'dart:math';

import 'package:flutter/material.dart';

/// アプリ共通のサイバーパンク風背景。以前は横線が奥から手前へ流れる
/// アニメーションだったが、視認性を優先して静止画にしている。
class FuturisticBackground extends StatelessWidget {
  const FuturisticBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0A24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _FuturisticGridPainter()),
          child,
        ],
      ),
    );
  }
}

class _FuturisticGridPainter extends CustomPainter {
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
    final horizonY = size.height * 0.38;

    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0B0A24),
          const Color(0xFF1A0F45),
          const Color(0xFF3A1264),
        ],
        stops: [0, horizonY / size.height, 1],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF3DAE).withValues(alpha: 0.55),
          const Color(0xFFFF3DAE).withValues(alpha: 0.0),
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
      ..color = const Color(0xFF33F7FF).withValues(alpha: 0.85)
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
        ..color = const Color(0xFF33F7FF).withValues(alpha: fade * 0.5)
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final horizonGlowPaint = Paint()
      ..color = const Color(0xFF33F7FF).withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      horizonGlowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FuturisticGridPainter oldDelegate) => false;
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
