import 'dart:math';
import 'package:flutter/material.dart';

class CallBackground extends StatelessWidget {
  final bool isVideoMode;
  final bool engineReady;

  const CallBackground({
    super.key,
    required this.isVideoMode,
    required this.engineReady,
  });

  @override
  Widget build(BuildContext context) {
    if (isVideoMode && engineReady) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0E21),
            Color(0xFF1A1A3E),
            Color(0xFF0D2B6B),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _ParticlePainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03);
    final rng = Random(42);
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 3 + 1;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
