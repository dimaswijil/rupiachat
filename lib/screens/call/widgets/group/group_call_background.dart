import 'package:flutter/material.dart';

class GroupCallBackground extends StatelessWidget {
  const GroupCallBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0F1A),
            Color(0xFF0D2B6B),
            Color(0xFF0A0F1A),
          ],
        ),
      ),
    );
  }
}
