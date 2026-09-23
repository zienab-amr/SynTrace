import 'dart:math';
import 'package:flutter/material.dart';

class NetworkPainter extends CustomPainter {
  final Color glowColor;
  final Color nodeColor;
  final double animationValue; // 0.0 → 1.0

  NetworkPainter({
    required this.glowColor,
    required this.nodeColor,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isDesktop = size.width >= 900;
    final center = Offset(size.width / 2, size.height / 2);

    // ═══════ 1. Glow مركزي هادي ═══════
    final glowRadius = isDesktop ? 500.0 : 300.0;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withOpacity(0.10),
          glowColor.withOpacity(0.03),
          glowColor.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

    canvas.drawCircle(center, glowRadius, glowPaint);

    // ═══════ 2. نقط Pulse ═══════
    final random = Random(42);
    final int nodeCount = isDesktop ? 14 : 10;
    final double iconZone = isDesktop ? 200.0 : 150.0; // منطقة محيطة باللوجو

    for (int i = 0; i < nodeCount; i++) {
      // موقع النقطة
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final point = Offset(x, y);

      // نتجنب المنطقة حوالين اللوجو
      if ((point - center).distance < iconZone) continue;

      // حجم متغير حسب الأنيميشن (Pulse)
      // كل نقطة ليها phase مختلفة
      final phase = (i * 0.37) % 1.0;
      final pulse = (sin((animationValue + phase) * 2 * pi) + 1) / 2; // 0 → 1

      final radius = 2.0 + (pulse * 1.5); // بين 2 و 3.5
      final opacity = 0.15 + (pulse * 0.35); // بين 0.15 و 0.5

      // رسم النقطة
      final nodePaint = Paint()
        ..color = nodeColor.withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(point, radius, nodePaint);

      // Halo خفيف حوالين النقطة
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            nodeColor.withOpacity((opacity * 0.3).clamp(0.0, 1.0)),
            nodeColor.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: point, radius: radius * 4));

      canvas.drawCircle(point, radius * 4, haloPaint);
    }
  }

  @override
  bool shouldRepaint(covariant NetworkPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.nodeColor != nodeColor;
  }
}