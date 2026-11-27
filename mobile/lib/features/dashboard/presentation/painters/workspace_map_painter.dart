import 'dart:math' as math;

import 'package:flutter/material.dart';

class WorkspaceMapPainter extends CustomPainter {
  final Color primary;
  final Color surface;
  final int projectCount;
  final Animation<double> animation;

  WorkspaceMapPainter({
    required this.primary,
    required this.surface,
    required this.projectCount,
    required this.animation,
  }) : super(repaint: animation);

  static const int maxVisibleNodes = 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);

    final radius = math.min(size.width, size.height) * 0.32;

    final progress = animation.value;

    _drawOrbit(canvas, center, radius);

    final count = math.min(projectCount, maxVisibleNodes);

    for (var i = 0; i < count; i++) {
      final angle = (math.pi * 2 * i / count) - math.pi / 2;

      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );

      final delay = i * 0.035;

      final reveal = ((progress - delay) / (1 - delay))
          .clamp(0.0, 1.0)
          .toDouble();

      if (reveal == 0) continue;

      _drawConnection(canvas, center, point, reveal);

      _drawProjectNode(canvas, point, reveal);
    }

    _drawWorkspace(canvas, center);
  }

  void _drawOrbit(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65
      ..color = primary.withValues(alpha: 0.13);

    for (final scale in [0.48, 0.75, 1.0]) {
      canvas.drawCircle(center, radius * scale, paint);
    }

    final dotPaint = Paint()..color = primary.withValues(alpha: 0.16);

    for (var i = 0; i < 48; i++) {
      final angle = i * math.pi * 2 / 48;

      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * radius * 1.22,
          center.dy + math.sin(angle) * radius * 1.22,
        ),
        0.8,
        dotPaint,
      );
    }
  }

  void _drawConnection(
    Canvas canvas,
    Offset center,
    Offset point,
    double progress,
  ) {
    final control = Offset(
      center.dx + (point.dx - center.dx) * 0.8,
      center.dy + (point.dy - center.dy) * 0.2,
    );

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(control.dx, control.dy, point.dx, point.dy);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = primary.withValues(alpha: 0.38);

    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }

    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  void _drawProjectNode(Canvas canvas, Offset center, double progress) {
    final opacity = ((progress - 0.65) / 0.35).clamp(0.0, 1.0).toDouble();

    if (opacity <= 0) return;

    canvas.drawCircle(
      center,
      15,
      Paint()..color = primary.withValues(alpha: 0.06 * opacity),
    );

    canvas.drawCircle(
      center,
      11,
      Paint()..color = surface.withValues(alpha: opacity),
    );

    canvas.drawCircle(
      center,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = primary.withValues(alpha: opacity * 0.45),
    );

    final folder = Path()
      ..moveTo(center.dx - 5, center.dy - 3)
      ..lineTo(center.dx - 5, center.dy - 5)
      ..lineTo(center.dx - 1, center.dy - 5)
      ..lineTo(center.dx + 1, center.dy - 3)
      ..lineTo(center.dx + 5, center.dy - 3)
      ..lineTo(center.dx + 5, center.dy + 4)
      ..lineTo(center.dx - 5, center.dy + 4)
      ..close();

    canvas.drawPath(
      folder,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round
        ..color = primary.withValues(alpha: opacity),
    );
  }

  void _drawWorkspace(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      32,
      Paint()
        ..shader = RadialGradient(
          colors: [
            primary.withValues(alpha: 0.14),
            primary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 32)),
    );

    canvas.drawCircle(center, 21, Paint()..color = surface);

    canvas.drawCircle(
      center,
      21,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = primary.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant WorkspaceMapPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.surface != surface ||
        oldDelegate.projectCount != projectCount ||
        oldDelegate.animation != animation;
  }
}
