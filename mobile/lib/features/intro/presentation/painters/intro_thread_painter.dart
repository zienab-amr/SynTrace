import 'dart:math' as math;
import 'package:flutter/material.dart';

class IntroThreadPainter extends CustomPainter {
  final Color color;
  final Animation<double> reveal;
  final Animation<double> motion;
  final bool isDark;

  IntroThreadPainter({
    required this.color,
    required this.reveal,
    required this.motion,
    required this.isDark,
  }) : super(repaint: Listenable.merge([reveal, motion]));

  static const double _width = 360;
  static const double _height = 340;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final scale = math.min(size.width / _width, size.height / _height);

    canvas.save();

    canvas.translate(
      (size.width - _width * scale) / 2,
      (size.height - _height * scale) / 2,
    );

    canvas.scale(scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, _width, _height));

    final phase = motion.value * math.pi * 2;
    final drift = math.sin(phase) * 4;

    _drawAmbient(canvas);
    _drawGrid(canvas);
    _drawPrimaryThreads(canvas, drift);
    _drawSecondaryThreads(canvas, drift);
    _drawFocus(canvas, drift);

    canvas.restore();
  }

  void _drawAmbient(Canvas canvas) {
    const center = Offset(190, 170);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: isDark ? 0.09 : 0.045),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 155));

    canvas.drawCircle(center, 155, paint);
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = color.withValues(alpha: isDark ? 0.09 : 0.07);

    for (double x = 20; x < _width; x += 20) {
      for (double y = 20; y < _height; y += 20) {
        canvas.drawCircle(Offset(x, y), 0.65, paint);
      }
    }
  }

  void _drawPrimaryThreads(Canvas canvas, double drift) {
    const count = 30;

    for (var i = 0; i < count; i++) {
      final t = i / (count - 1);

      final startY = 45 + t * 220;
      final centerX = 170 + t * 42;
      final centerY = 145 + t * 35 + drift;

      final path = Path()
        ..moveTo(-20, startY)
        ..cubicTo(
          70,
          startY - 45,
          100 + t * 40,
          250 - t * 130,
          centerX,
          centerY,
        )
        ..cubicTo(
          240 + t * 30,
          centerY - 75,
          300,
          20 + t * 100,
          380,
          65 + t * 140,
        );

      final intensity = math.sin(t * math.pi);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.75 + intensity * 0.35
        ..color = color.withValues(
          alpha: (isDark ? 0.12 : 0.10) + intensity * 0.32,
        );

      _drawRevealedPath(canvas, path, paint, delay: t * 0.22);
    }
  }

  void _drawSecondaryThreads(Canvas canvas, double drift) {
    const count = 16;

    for (var i = 0; i < count; i++) {
      final t = i / (count - 1);

      final path = Path()
        ..moveTo(55 + t * 85, 360)
        ..cubicTo(
          35 + t * 80,
          235,
          230 - t * 40,
          245,
          170 + t * 42,
          145 + t * 35 + drift,
        )
        ..cubicTo(140 + t * 75, 85, 250 + t * 40, 55, 245 + t * 60, -20);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.10 + t * 0.13);

      _drawRevealedPath(canvas, path, paint, delay: 0.15 + t * 0.2);
    }
  }

  void _drawRevealedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double delay,
  }) {
    final progress = ((reveal.value - delay) / (1 - delay))
        .clamp(0.0, 1.0)
        .toDouble();

    if (progress <= 0) return;

    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }

    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  void _drawFocus(Canvas canvas, double drift) {
    final opacity = ((reveal.value - 0.55) / 0.45).clamp(0.0, 1.0).toDouble();

    if (opacity <= 0) return;

    final center = Offset(191, 162 + drift);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = color.withValues(alpha: opacity * 0.3);

    canvas.drawCircle(center, 24, ringPaint);
    canvas.drawCircle(center, 37, ringPaint);

    final corePaint = Paint()..color = color.withValues(alpha: opacity * 0.9);

    canvas.drawCircle(center, 3.5, corePaint);

    final nodes = [
      const Offset(64, 110),
      const Offset(282, 94),
      const Offset(102, 262),
    ];

    for (final node in nodes) {
      canvas.drawCircle(node, 5.5, ringPaint);
      canvas.drawCircle(node, 2, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant IntroThreadPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isDark != isDark ||
        oldDelegate.reveal != reveal ||
        oldDelegate.motion != motion;
  }
}
