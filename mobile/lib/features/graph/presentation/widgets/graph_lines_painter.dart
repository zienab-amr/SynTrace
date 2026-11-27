import 'dart:math';
import 'package:flutter/material.dart';
import 'package:syntrace/features/graph/data/models/graph_models.dart';

class GraphLinesPainter extends CustomPainter {
  final List<GraphEdge> edges;
  final String? selectedNodeId;
  final Map<String, Offset> nodePositions;
  final bool isDark;
  GraphLinesPainter({
    required this.edges,
    this.selectedNodeId,
    required this.nodePositions,
    required this.isDark,
  });

  Offset _getPos(GraphNode node) {
    return nodePositions[node.id] ?? node.position;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final defaultLineColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.1);

    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.6);

    final labelBgColor = isDark
        ? const Color(0xFF0A0E1A).withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.8);

    for (var edge in edges) {
      final isConnectedToSelected =
          selectedNodeId == null ||
          edge.source.id == selectedNodeId ||
          edge.target.id == selectedNodeId;

      if (!isConnectedToSelected) continue;

      final isEdgeSelected =
          selectedNodeId != null &&
          (edge.source.id == selectedNodeId ||
              edge.target.id == selectedNodeId);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isEdgeSelected ? 3.0 : 1.5
        ..color = isEdgeSelected
            ? edge.source.color.withValues(alpha: 0.9)
            : defaultLineColor;

      final start = _getPos(edge.source);
      final end = _getPos(edge.target);

      final angle = atan2(end.dy - start.dy, end.dx - start.dx);
      final nodeRadius = 35.0;
      final lineEnd = Offset(
        end.dx - nodeRadius * cos(angle),
        end.dy - nodeRadius * sin(angle),
      );

      final path = Path();
      path.moveTo(start.dx, start.dy);

      final controlPoint1 = Offset(
        start.dx + (lineEnd.dx - start.dx) / 2,
        start.dy,
      );
      final controlPoint2 = Offset(
        start.dx + (lineEnd.dx - start.dx) / 2,
        lineEnd.dy,
      );

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        lineEnd.dx,
        lineEnd.dy,
      );

      canvas.drawPath(path, paint);

      if (isEdgeSelected || selectedNodeId == null) {
        _drawArrowHead(canvas, lineEnd, angle, paint.color);
      }

      final String labelText = _getEdgeLabel(edge);
      if (labelText.isNotEmpty) {
        _drawEdgeLabel(
          canvas,
          start,
          controlPoint1,
          controlPoint2,
          lineEnd,
          labelText,
          isEdgeSelected,
          textColor,
          labelBgColor,
        );
      }
    }
  }

  String _getEdgeLabel(GraphEdge edge) {
    try {
      final dynamic e = edge;
      return e.label ?? e.type ?? 'RELATES';
    } catch (_) {
      return 'RELATES';
    }
  }

  void _drawEdgeLabel(
    Canvas canvas,
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    String text,
    bool isSelected,
    Color textColor,
    Color bgColor,
  ) {
    final t = 0.5;
    final mt = 1 - t;
    final x =
        mt * mt * mt * p0.dx +
        3 * mt * mt * t * p1.dx +
        3 * mt * t * t * p2.dx +
        t * t * t * p3.dx;
    final y =
        mt * mt * mt * p0.dy +
        3 * mt * mt * t * p1.dy +
        3 * mt * t * t * p2.dy +
        t * t * t * p3.dy;
    final midPoint = Offset(x, y);

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: isSelected ? (isDark ? Colors.white : Colors.black) : textColor,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        backgroundColor: bgColor,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        midPoint.dx - (textPainter.width / 2),
        midPoint.dy - (textPainter.height / 2),
      ),
    );
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset position,
    double angle,
    Color color,
  ) {
    final path = Path();
    const arrowWidth = 10.0;

    path.moveTo(position.dx, position.dy);
    path.lineTo(
      position.dx - arrowWidth * cos(angle - pi / 6),
      position.dy - arrowWidth * sin(angle - pi / 6),
    );
    path.lineTo(
      position.dx - arrowWidth * cos(angle + pi / 6),
      position.dy - arrowWidth * sin(angle + pi / 6),
    );
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
