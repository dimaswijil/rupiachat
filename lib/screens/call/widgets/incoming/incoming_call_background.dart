import 'package:flutter/material.dart';

class IncomingCallBackground extends StatelessWidget {
  const IncomingCallBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0C0E14),
            Color(0xFF13161C),
            Color(0xFF181B22),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: const SizedBox.shrink(),
    );
  }
}

