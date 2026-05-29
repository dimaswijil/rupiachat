import 'package:flutter/material.dart';

class GroupCallControls extends StatelessWidget {
  final bool isVideoMode;
  final bool muted;
  final bool cameraOff;
  final bool speakerOn;
  final VoidCallback onMute;
  final VoidCallback onCamera;
  final VoidCallback onSpeaker;
  final VoidCallback onEndCall;

  const GroupCallControls({
    super.key,
    required this.isVideoMode,
    required this.muted,
    required this.cameraOff,
    required this.speakerOn,
    required this.onMute,
    required this.onCamera,
    required this.onSpeaker,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlBtn(
            icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: muted ? 'Unmute' : 'Mute',
            active: muted,
            onTap: onMute,
          ),
          if (isVideoMode)
            _buildControlBtn(
              icon: cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
              label: cameraOff ? 'Kamera On' : 'Kamera Off',
              active: cameraOff,
              onTap: onCamera,
            ),
          _buildControlBtn(
            icon: speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
            label: speakerOn ? 'Speaker' : 'Earpiece',
            active: speakerOn,
            onTap: onSpeaker,
          ),
          // End call button
          GestureDetector(
            onTap: onEndCall,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
              ),
              child: const Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.white.withOpacity(0.2)
                  : Colors.white.withOpacity(0.08),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Icon(
              icon,
              color: active ? const Color(0xFFEF4444) : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
