import 'dart:math';
import 'package:flutter/material.dart';

class NetworkPainter extends CustomPainter {
  final Color glowColor;
  final Color nodeColor;
  final double animationValue;

  NetworkPainter({
    required this.glowColor,
    required this.nodeColor,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final isDesktop = size.width >= 900;

    final center = Offset(size.width / 2, size.height / 2);

    final random = Random(42);
    final nodeCount = isDesktop ? 14 : 10;
    final iconZone = isDesktop ? 200.0 : 150.0;

    final nodes = <Offset>[];
    final indices = <int>[];

    for (int i = 0; i < nodeCount; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );

      if ((point - center).distance < iconZone) {
        continue;
      }

      nodes.add(point);
      indices.add(i);
    }

    // Draw subtle connections behind the nodes.
    _drawConnections(canvas, size, nodes);

    // Draw the original pulsing nodes.
    for (int i = 0; i < nodes.length; i++) {
      _drawNode(canvas, nodes[i], indices[i]);
    }
  }

  void _drawConnections(Canvas canvas, Size size, List<Offset> nodes) {
    final maxDistance = size.shortestSide * 0.65;

    final paint = Paint()
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final distance = (nodes[i] - nodes[j]).distance;

        if (distance > maxDistance) continue;

        final pulse = (sin((animationValue + (i + j) * 0.15) * 2 * pi) + 1) / 2;

        final distanceFactor = 1 - (distance / maxDistance);

        final opacity = (0.08 + pulse * 0.08) * distanceFactor;

        paint.color = nodeColor.withValues(alpha: opacity);

        canvas.drawLine(nodes[i], nodes[j], paint);
      }
    }
  }

  void _drawNode(Canvas canvas, Offset point, int index) {
    final phase = (index * 0.37) % 1.0;

    final pulse = (sin((animationValue + phase) * 2 * pi) + 1) / 2;

    final radius = 2.0 + pulse * 1.2;
    final opacity = 0.15 + pulse * 0.25;
    final haloRadius = radius * 2.5;

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          nodeColor.withValues(alpha: opacity * 0.20),
          nodeColor.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: point, radius: haloRadius));

    canvas.drawCircle(point, haloRadius, haloPaint);

    final nodePaint = Paint()
      ..color = nodeColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(point, radius, nodePaint);
  }

  @override
  bool shouldRepaint(covariant NetworkPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.nodeColor != nodeColor;
  }
}
