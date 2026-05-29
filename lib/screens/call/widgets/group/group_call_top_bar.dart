import 'package:flutter/material.dart';

class GroupCallTopBar extends StatelessWidget {
  final String groupName;
  final bool localJoined;
  final int participantCount;
  final bool isVideoMode;
  final int seconds;
  final VoidCallback onEndCall;
  final VoidCallback onUpgradeToVideo;
  final VoidCallback onSwitchCamera;

  const GroupCallTopBar({
    super.key,
    required this.groupName,
    required this.localJoined,
    required this.participantCount,
    required this.isVideoMode,
    required this.seconds,
    required this.onEndCall,
    required this.onUpgradeToVideo,
    required this.onSwitchCamera,
  });

  String _formatTime(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onEndCall,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  groupName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  localJoined
                      ? '$participantCount peserta · ${_formatTime(seconds)}'
                      : 'Menghubungkan...',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!isVideoMode)
            IconButton(
              icon: const Icon(Icons.videocam_rounded, color: Colors.white70),
              tooltip: 'Upgrade ke Video',
              onPressed: onUpgradeToVideo,
            ),
          if (isVideoMode)
            IconButton(
              icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white70),
              onPressed: onSwitchCamera,
            ),
        ],
      ),
    );
  }
}
