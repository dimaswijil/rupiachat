import 'package:flutter/material.dart';

class IncomingCallAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final Animation<double> pulseAnimation;

  const IncomingCallAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow rings
        ...List.generate(3, (i) {
          return AnimatedBuilder(
            animation: pulseAnimation,
            builder: (_, __) {
              final scale = 1.0 + (i + 1) * 0.15 * pulseAnimation.value;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2557B3).withOpacity(0.15 - (i * 0.04)),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          );
        }),
        // Main avatar
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2557B3), Color(0xFF0D2060)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2557B3).withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: hasPhoto
              ? ClipOval(
                  child: Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
