import 'package:flutter/material.dart';
import '../../../../utils/colors.dart';

class GroupCallVoiceUI extends StatelessWidget {
  final List<int> remoteUserIds;
  final Animation<double> pulseAnimation;

  const GroupCallVoiceUI({
    super.key,
    required this.remoteUserIds,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Group icon
          ScaleTransition(
            scale: pulseAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF2557B3), Color(0xFF0D2060)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: RupiaColors.primary.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 24),

          // Participants list
          if (remoteUserIds.isEmpty)
            const Text(
              'Menunggu peserta lain bergabung...',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: remoteUserIds.map((uid) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Center(
                        child: Text(
                          'U$uid',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Peserta ${remoteUserIds.indexOf(uid) + 1}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
