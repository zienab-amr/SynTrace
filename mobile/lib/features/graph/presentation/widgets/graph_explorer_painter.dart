import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:syntrace/features/graph/data/models/graph_models.dart';

String graphTypeLabel(NodeType type) => switch (type) {
  NodeType.project => 'Project',
  NodeType.task => 'Task',
  NodeType.bug => 'Bug',
  NodeType.developer => 'Developer',
  NodeType.commit => 'Commit',
  NodeType.repository => 'Repository',
  NodeType.pullRequest => 'Pull request',
  NodeType.jira => 'Jira',
};

Color graphTypeColor(NodeType type, bool dark) => switch (type) {
  NodeType.project => dark ? const Color(0xFF9AA9F5) : const Color(0xFF4B5AC5),
  NodeType.task => dark ? const Color(0xFF77CAD3) : const Color(0xFF187C8A),
  NodeType.bug => dark ? const Color(0xFFF19A9F) : const Color(0xFFB44354),
  NodeType.developer =>
    dark ? const Color(0xFFC1A7E8) : const Color(0xFF7953AD),
  NodeType.commit => dark ? const Color(0xFF83C7AA) : const Color(0xFF267F5C),
  NodeType.repository =>
    dark ? const Color(0xFF81B5E5) : const Color(0xFF32699F),
  NodeType.pullRequest =>
    dark ? const Color(0xFFE7B879) : const Color(0xFFA66B25),
  NodeType.jira => dark ? const Color(0xFF82A8DE) : const Color(0xFF405FA1),
};

IconData graphTypeIcon(NodeType type) => switch (type) {
  NodeType.project => Icons.folder_outlined,
  NodeType.task => Icons.check_circle_outline_rounded,
  NodeType.bug => Icons.bug_report_outlined,
  NodeType.developer => Icons.person_outline_rounded,
  NodeType.commit => Icons.code_rounded,
  NodeType.repository => Icons.inventory_2_outlined,
  NodeType.pullRequest => Icons.merge_type_rounded,
  NodeType.jira => Icons.assignment_outlined,
};

double graphNodeRadius(GraphNode node) =>
    node.type == NodeType.project ? 29 : 23;

class GraphGridPainter extends CustomPainter {
  GraphGridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double x = 12; x < size.width; x += 24) {
      for (double y = 12; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GraphGridPainter oldDelegate) =>
      color != oldDelegate.color;
}

class GraphExplorerPainter extends CustomPainter {
  GraphExplorerPainter({
    required this.nodes,
    required this.edges,
    required this.positions,
    required this.selectedId,
    required this.relatedIds,
    required this.scheme,
    required this.detailLevel,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Map<String, Offset> positions;
  final String? selectedId;
  final Set<String> relatedIds;
  final ColorScheme scheme;
  final int detailLevel;

  bool get _dark => scheme.brightness == Brightness.dark;
  bool _focused(String id) =>
      selectedId == null || id == selectedId || relatedIds.contains(id);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final edge in edges) {
      final a = positions[edge.source.id];
      final b = positions[edge.target.id];
      if (a == null || b == null) continue;
      final difference = b - a;
      final length = difference.distance;
      final highlighted =
          selectedId != null &&
          (edge.source.id == selectedId || edge.target.id == selectedId);
      final color = highlighted
          ? graphTypeColor(edge.source.type, _dark).withValues(alpha: 0.84)
          : scheme.onSurface.withValues(
              alpha: selectedId == null ? (_dark ? 0.24 : 0.20) : 0.055,
            );
      if (length <=
          graphNodeRadius(edge.source) + graphNodeRadius(edge.target) + 4) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = highlighted ? 2.1 : 1.1
          ..color = color;
        final radius = math.max(
          graphNodeRadius(edge.source),
          graphNodeRadius(edge.target),
        );
        final center = (a + b) / 2;
        canvas.drawArc(
          Rect.fromCircle(
            center: center + Offset(0, -radius),
            radius: radius * 0.85,
          ),
          math.pi * 0.1,
          math.pi * 1.8,
          false,
          paint,
        );
        continue;
      }
      final unit = difference / length;
      final start = a + unit * graphNodeRadius(edge.source);
      final end = b - unit * (graphNodeRadius(edge.target) + 3);
      final normal = Offset(-unit.dy, unit.dx);
      final bend = math.min(28.0, length * 0.11);
      final control = (start + end) / 2 + normal * bend;
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? 2.1 : 1.1
        ..color = color;
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy),
        paint,
      );
      if (highlighted || (detailLevel == 2 && selectedId == null)) {
        final direction = end - control;
        final angle = math.atan2(direction.dy, direction.dx);
        final left =
            end - Offset(math.cos(angle - 0.48), math.sin(angle - 0.48)) * 7;
        final right =
            end - Offset(math.cos(angle + 0.48), math.sin(angle + 0.48)) * 7;
        paint.style = PaintingStyle.fill;
        canvas.drawPath(
          Path()
            ..moveTo(end.dx, end.dy)
            ..lineTo(left.dx, left.dy)
            ..lineTo(right.dx, right.dy)
            ..close(),
          paint,
        );
      }
    }

    for (final node in nodes) {
      final center = positions[node.id];
      if (center == null) continue;
      final selected = node.id == selectedId;
      final focused = _focused(node.id);
      final radius = graphNodeRadius(node);
      final accent = graphTypeColor(node.type, _dark);
      final opacity = focused ? 1.0 : 0.23;
      final fill = Color.lerp(scheme.surface, accent, _dark ? 0.13 : 0.09)!;
      if (selected) {
        paint
          ..style = PaintingStyle.fill
          ..color = accent.withValues(alpha: 0.11);
        canvas.drawCircle(center, radius + 9, paint);
      }
      paint
        ..style = PaintingStyle.fill
        ..color = Color.lerp(scheme.surface, fill, opacity)!;
      canvas.drawCircle(center, radius, paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = (selected ? 2.7 : 1.45)
        ..color = accent.withValues(alpha: focused ? 0.92 : 0.23);
      canvas.drawCircle(center, radius, paint);
      if (detailLevel > 0 || selected) {
        final icon = graphTypeIcon(node.type);
        _text(
          canvas,
          String.fromCharCode(icon.codePoint),
          center,
          accent.withValues(alpha: opacity),
          radius * 0.83,
          fontFamily: icon.fontFamily,
          fontPackage: icon.fontPackage,
        );
      } else {
        paint
          ..style = PaintingStyle.fill
          ..color = accent.withValues(alpha: opacity);
        canvas.drawCircle(center, 4, paint);
      }
    }

    // Reserve labels for focused nodes and avoid overlapping other labels.
    final candidates = nodes
        .where(
          (node) =>
              _focused(node.id) &&
              (node.id == selectedId ||
                  detailLevel == 2 ||
                  (detailLevel == 1 && node.type == NodeType.project)),
        )
        .toList();
    int priority(GraphNode node) => node.id == selectedId
        ? 0
        : node.type == NodeType.project
        ? 1
        : 2;
    candidates.sort((a, b) => priority(a).compareTo(priority(b)));
    final occupied = <Rect>[];
    final nodeBounds = [
      for (final node in nodes)
        if (positions[node.id] != null)
          Rect.fromCircle(
            center: positions[node.id]!,
            radius: graphNodeRadius(node) + 2,
          ),
    ];
    for (final node in candidates) {
      if (occupied.length >= 100) break;
      final center = positions[node.id];
      if (center == null || node.label.isEmpty) continue;
      final selected = node.id == selectedId;
      final text = TextPainter(
        text: TextSpan(
          text: node.label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: selected ? 1 : 0.85),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 130);
      final origin =
          center + Offset(-text.width / 2, graphNodeRadius(node) + 8);
      final bounds = (origin & Size(text.width, text.height)).inflate(3);
      if (selected ||
          (!occupied.any(bounds.overlaps) &&
              !nodeBounds.any(bounds.overlaps))) {
        text.paint(canvas, origin);
        occupied.add(bounds);
      }
      text.dispose();
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset center,
    Color color,
    double size, {
    String? fontFamily,
    String? fontPackage,
    double maxWidth = 160,
  }) {
    if (value.isEmpty) return;
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: fontFamily,
          package: fontPackage,
          fontWeight: fontFamily == null ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: fontFamily == null ? '…' : null,
    )..layout(maxWidth: maxWidth);
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    text.dispose();
  }

  @override
  bool shouldRepaint(covariant GraphExplorerPainter oldDelegate) =>
      oldDelegate.nodes != nodes ||
      oldDelegate.edges != edges ||
      oldDelegate.positions != positions ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.relatedIds != relatedIds ||
      oldDelegate.scheme != scheme ||
      oldDelegate.detailLevel != detailLevel;
}
