import 'package:flutter/material.dart';
import '../../../../utils/colors.dart';

class CallCenterProfile extends StatelessWidget {
  final String otherUserName;
  final String? otherUserPhoto;
  final bool isVideoMode;
  final bool joined;
  final bool remoteUserJoined;
  final int seconds;
  final Animation<double> pulseAnimation;

  const CallCenterProfile({
    super.key,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.isVideoMode,
    required this.joined,
    required this.remoteUserJoined,
    required this.seconds,
    required this.pulseAnimation,
  });

  String _formatDuration(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final initials = otherUserName.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    final hasPhoto = otherUserPhoto != null && otherUserPhoto!.isNotEmpty;

    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (!remoteUserJoined)
                  ...List.generate(3, (i) {
                    return AnimatedBuilder(
                      animation: pulseAnimation,
                      builder: (_, __) {
                        final scale = 1.0 + (i + 1) * 0.12 * pulseAnimation.value;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2557B3).withOpacity(0.2 - (i * 0.05)),
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                AnimatedBuilder(
                  animation: pulseAnimation,
                  builder: (_, child) {
                    final scale = remoteUserJoined ? 1.0 : pulseAnimation.value;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasPhoto ? null : const LinearGradient(
                        colors: [Color(0xFF2557B3), Color(0xFF0D2060)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2557B3).withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                      image: hasPhoto ? DecorationImage(
                        image: NetworkImage(otherUserPhoto!),
                        fit: BoxFit.cover,
                      ) : null,
                    ),
                    child: hasPhoto ? null : Center(
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
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              otherUserName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            if (remoteUserJoined)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(seconds),
                      style: const TextStyle(
                        color: RupiaColors.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              _buildCallingStatus(),
            const SizedBox(height: 8),
            Text(
              isVideoMode ? '📹 Panggilan Video' : '📞 Panggilan Suara',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallingStatus() {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: 100),
      duration: const Duration(seconds: 100),
      builder: (_, val, __) {
        final dots = '.' * ((val % 3) + 1);
        final text = joined ? 'Memanggil$dots' : 'Menghubungkan$dots';
        return Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
          ),
        );
      },
    );
  }
}
