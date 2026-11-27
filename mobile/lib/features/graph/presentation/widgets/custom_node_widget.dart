import 'package:flutter/material.dart';
import 'package:syntrace/features/graph/data/models/graph_models.dart';

class CustomNodeWidget extends StatelessWidget {
  final GraphNode node;
  final bool isSelected;
  final bool isDimmed;
  final VoidCallback onTap;
  final Function(Offset) onDrag;
  final double nodeSize;

  const CustomNodeWidget({
    super.key,
    required this.node,
    required this.isSelected,
    required this.isDimmed,
    required this.onTap,
    required this.onDrag,
    this.nodeSize = 70.0,
  });

  @override
  Widget build(BuildContext context) {
    final double currentSize = isSelected ? nodeSize * 1.1 : nodeSize;
    final double fontSize = nodeSize * 0.18;
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (details) => onDrag(details.delta),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isDimmed ? 0.15 : 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: currentSize,
                height: currentSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: node.color.withValues(alpha: 0.9),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : node.color.withValues(alpha: 0.4),
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: node.color.withValues(
                        alpha: isSelected ? 0.8 : 0.4,
                      ),
                      blurRadius: isSelected ? 30 : 15,
                      spreadRadius: isSelected ? 8 : 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(nodeSize * 0.1),
                    child: Text(
                      node.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
