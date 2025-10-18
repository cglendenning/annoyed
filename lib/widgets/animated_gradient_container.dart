import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A container with animated gradient that creates a "living" feel
class AnimatedGradientContainer extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final Duration duration;
  final Alignment begin;
  final Alignment end;

  const AnimatedGradientContainer({
    super.key,
    required this.child,
    required this.colors,
    this.duration = const Duration(seconds: 3),
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  @override
  State<AnimatedGradientContainer> createState() =>
      _AnimatedGradientContainerState();
}

class _AnimatedGradientContainerState
    extends State<AnimatedGradientContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.lerp(
                widget.begin,
                widget.end,
                math.sin(_controller.value * math.pi) * 0.3,
              )!,
              end: Alignment.lerp(
                widget.end,
                widget.begin,
                math.cos(_controller.value * math.pi) * 0.3,
              )!,
              colors: widget.colors,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

