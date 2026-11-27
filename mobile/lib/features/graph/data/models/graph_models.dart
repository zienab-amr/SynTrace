import 'package:flutter/material.dart';

enum NodeType {
  project,
  task,
  bug,
  developer,
  commit,
  repository,
  pullRequest,
  jira,
}

class GraphNode {
  final String id;
  final String label;
  final String subLabel;
  final NodeType type;
  final Offset position; // (x, y) coordinates
  final int connections;
  final int openItems;
  final String riskLevel;

  GraphNode({
    required this.id,
    required this.label,
    this.subLabel = '',
    required this.type,
    required this.position,
    this.connections = 0,
    this.openItems = 0,
    this.riskLevel = 'Low',
  });

  Color get color {
    switch (type) {
      case NodeType.project:
        return const Color(0xFF00C48C);
      case NodeType.task:
        return const Color(0xFF2F80ED);
      case NodeType.bug:
        return const Color(0xFFEB5757);
      case NodeType.developer:
        return const Color(0xFF2F80ED);
      case NodeType.commit:
        return const Color(0xFF9B51E0);
      case NodeType.repository:
        return const Color(0xFF9B51E0);
      case NodeType.pullRequest:
        return const Color(0xFFF2994A);
      case NodeType.jira:
        return const Color(0xFF56CCF2);
    }
  }
}

class GraphEdge {
  final GraphNode source;
  final GraphNode target;
  GraphEdge(this.source, this.target);
}
