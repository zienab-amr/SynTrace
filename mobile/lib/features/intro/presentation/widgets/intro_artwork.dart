import 'package:flutter/material.dart';

import '../painters/intro_thread_painter.dart';

class IntroArtwork extends StatefulWidget {
  const IntroArtwork({super.key});

  @override
  State<IntroArtwork> createState() => _IntroArtworkState();
}

class _IntroArtworkState extends State<IntroArtwork>
    with TickerProviderStateMixin {
  late final AnimationController _reveal;
  late final AnimationController _motion;

  late final Animation<double> _curvedReveal;

  @override
  void initState() {
    super.initState();

    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    _curvedReveal = CurvedAnimation(
      parent: _reveal,
      curve: Curves.easeOutCubic,
    );

    _reveal.addStatusListener(_onRevealStatus);
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        mounted &&
        !MediaQuery.disableAnimationsOf(context) &&
        !_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      _reveal.stop();
      _motion.stop();

      _reveal.value = 1;
      _motion.value = 0;

      return;
    }

    if (!_reveal.isCompleted && !_reveal.isAnimating) {
      _reveal.forward();
    } else if (_reveal.isCompleted && !_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _reveal.removeStatusListener(_onRevealStatus);

    (_curvedReveal as CurvedAnimation).dispose();

    _reveal.dispose();
    _motion.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: CustomPaint(
        painter: IntroThreadPainter(
          color: theme.colorScheme.primary,
          reveal: _curvedReveal,
          motion: _motion,
          isDark: theme.brightness == Brightness.dark,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
