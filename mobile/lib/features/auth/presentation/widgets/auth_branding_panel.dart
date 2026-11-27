import 'dart:math';
import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class AuthBrandingPanel extends StatefulWidget {
  const AuthBrandingPanel({super.key});

  @override
  State<AuthBrandingPanel> createState() => _AuthBrandingPanelState();
}

class _AuthBrandingPanelState extends State<AuthBrandingPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: theme.colorScheme.surface,
      child: Stack(
        children: [
          // ═══ Graph Visual (Animated) ═══
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _GraphVisualPainter(
                    isDark: isDark,
                    animationValue: _controller.value,
                  ),
                );
              },
            ),
          ),

          // ═══ Content ═══
          Padding(
            padding: const EdgeInsets.all(64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ─── Top: Label ───
                Text(
                  'SOFTWARE ENGINEERING INTELLIGENCE',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),

                // ─── Middle: Headline ───
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          letterSpacing: -1.5,
                        ),
                        children: [
                          const TextSpan(text: 'Connect your\n'),
                          const TextSpan(text: 'engineering\n'),
                          TextSpan(
                            text: 'graph.',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text(
                        'SynTrace transforms fragmented GitHub data, '
                        'requirements, meetings, and tasks into connected '
                        'engineering intelligence — powered by knowledge '
                        'graphs and AI.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ─── Feature Chips ───
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _FeatureChip(label: 'Knowledge Graph'),
                        _FeatureChip(label: 'AI Root Cause'),
                        _FeatureChip(label: 'Sprint Intelligence'),
                        _FeatureChip(label: 'Security Guard'),
                        _FeatureChip(label: 'Real-time Sync'),
                      ],
                    ),
                  ],
                ),

                // Bottom: product overview
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product icon
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.hub_outlined,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Product description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Connect project activity, meeting notes, and '
                                'AI-assisted analysis in one workspace.',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.75,
                                  ),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'SynTrace · Engineering Intelligence',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Feature Chip
// ═══════════════════════════════════════════════════════════
class _FeatureChip extends StatelessWidget {
  final String label;

  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Graph Visual Painter — Animated
// ═══════════════════════════════════════════════════════════
class _GraphVisualPainter extends CustomPainter {
  final bool isDark;
  final double animationValue;
  const _GraphVisualPainter({
    required this.isDark,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = [
      _Node(Offset(size.width * 0.72, size.height * 0.12), 'Meeting'),
      _Node(Offset(size.width * 0.88, size.height * 0.28), 'Task'),
      _Node(Offset(size.width * 0.78, size.height * 0.42), 'Commit'),
      _Node(Offset(size.width * 0.92, size.height * 0.58), 'PR'),
      _Node(Offset(size.width * 0.68, size.height * 0.72), 'Bug'),
      _Node(Offset(size.width * 0.85, size.height * 0.88), 'Developer'),
    ];

    // Theme-dependent line opacity
    final lineOpacity = isDark ? 0.08 : 0.12;
    final linePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: lineOpacity)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final connections = [
      [0, 1],
      [1, 2],
      [2, 3],
      [2, 4],
      [4, 5],
      [1, 4],
      [0, 2],
    ];

    for (final conn in connections) {
      canvas.drawLine(
        nodes[conn[0]].position,
        nodes[conn[1]].position,
        linePaint,
      );
    }

    // ─── Colors ───
    final glowBase = isDark ? 0.15 : 0.10;
    final circleBase = isDark ? 0.25 : 0.20;
    final dotBase = isDark ? 0.5 : 0.4;
    final labelBase = isDark ? 0.4 : 0.35;

    // Pulsing nodes
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];

      // Pulse with a distinct phase for each node
      final phase = (i * 0.17) % 1.0;
      final pulse = (sin((animationValue + phase) * 2 * pi) + 1) / 2;

      // Animated sizes
      final glowRadius = 35 + (pulse * 10); // 35 → 45
      final circleRadius = 14 + (pulse * 3); // 14 → 17
      final dotRadius = 2.5 + (pulse * 1.0); // 2.5 → 3.5

      // Animated opacities
      final glowOpacity = glowBase + (pulse * 0.08);
      final circleOpacity = circleBase + (pulse * 0.10);
      final dotOpacity = dotBase + (pulse * 0.20);

      // ─── Glow ───
      final glowPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                AppColors.primary.withValues(alpha: glowOpacity),
                AppColors.primary.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(center: node.position, radius: glowRadius),
            );
      canvas.drawCircle(node.position, glowRadius, glowPaint);

      // ─── Outer Circle ───
      final circlePaint = Paint()
        ..color = AppColors.primary.withValues(alpha: circleOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(node.position, circleRadius, circlePaint);

      // ─── Inner Dot ───
      final dotPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: dotOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, dotRadius, dotPaint);

      // ─── Label ───
      final textPainter = TextPainter(
        text: TextSpan(
          text: node.label,
          style: TextStyle(
            color: AppColors.primary.withValues(alpha: labelBase),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, node.position + const Offset(-15, 22));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphVisualPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isDark != isDark;
  }
}

class _Node {
  final Offset position;
  final String label;

  _Node(this.position, this.label);
}
