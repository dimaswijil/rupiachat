import 'package:flutter/material.dart';

class CallControls extends StatelessWidget {
  final bool isVideoMode;
  final bool muted;
  final bool speakerOn;
  final bool cameraOff;
  final bool joined;
  final bool remoteUserJoined;
  final bool controlsVisible;
  final int seconds;
  final VoidCallback onMute;
  final VoidCallback onSpeaker;
  final VoidCallback onCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onUpgradeToVideo;
  final VoidCallback onEndCall;

  const CallControls({
    super.key,
    required this.isVideoMode,
    required this.muted,
    required this.speakerOn,
    required this.cameraOff,
    required this.joined,
    required this.remoteUserJoined,
    required this.controlsVisible,
    required this.seconds,
    required this.onMute,
    required this.onSpeaker,
    required this.onCamera,
    required this.onSwitchCamera,
    required this.onUpgradeToVideo,
    required this.onEndCall,
  });

  String _formatDuration(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildTopBar(context),
        _buildBottomControls(context),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 16,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.6), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: onEndCall,
              ),
              const Spacer(),
              if (remoteUserJoined && isVideoMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF4ADE80),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4ADE80).withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(seconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              if (!isVideoMode)
                IconButton(
                  icon: const Icon(Icons.videocam_rounded, color: Colors.white70, size: 26),
                  tooltip: 'Upgrade ke Video',
                  onPressed: onUpgradeToVideo,
                ),
              if (isVideoMode)
                IconButton(
                  icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white70, size: 24),
                  tooltip: 'Putar Kamera',
                  onPressed: onSwitchCamera,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    final List<Widget> controlButtons = [
      _GlassButton(
        icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
        label: muted ? 'Unmute' : 'Mute',
        isActive: muted,
        onTap: onMute,
      ),
      if (!isVideoMode)
        _GlassButton(
          icon: speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
          label: speakerOn ? 'Speaker' : 'Earpiece',
          isActive: speakerOn,
          onTap: onSpeaker,
        ),
      if (isVideoMode)
        _GlassButton(
          icon: cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
          label: 'Kamera',
          isActive: cameraOff,
          onTap: onCamera,
        ),
      if (!isVideoMode && joined)
        _GlassButton(
          icon: Icons.videocam_rounded,
          label: 'Video',
          onTap: onUpgradeToVideo,
        ),
      if (isVideoMode)
        _GlassButton(
          icon: Icons.cameraswitch_rounded,
          label: 'Putar',
          onTap: onSwitchCamera,
        ),
    ];

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 24,
            right: 24,
            top: 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ...controlButtons,
                _GlassButton(
                  icon: Icons.call_end_rounded,
                  label: 'Tutup',
                  isEndCall: true,
                  onTap: onEndCall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isEndCall;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.isEndCall = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isEndCall
                  ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
                  : null,
              color: isEndCall
                  ? null
                  : isActive
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.08),
              border: isEndCall
                  ? null
                  : Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Icon(
              icon,
              color: isEndCall
                  ? Colors.white
                  : isActive
                      ? const Color(0xFFEF4444)
                      : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isEndCall ? const Color(0xFFEF4444) : Colors.white60,
              fontSize: 10,
              fontWeight: isEndCall ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
