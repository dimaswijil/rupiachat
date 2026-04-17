import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/colors.dart';

// ── Ganti dengan App ID Agora Anda dari console.agora.io ──
const String agoraAppId = 'YOUR_AGORA_APP_ID';

class CallScreen extends StatefulWidget {
  final String channelName;
  final String otherUserName;
  final bool isVideoCall;

  const CallScreen({
    super.key,
    required this.channelName,
    required this.otherUserName,
    required this.isVideoCall,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine _engine;
  bool _joined = false;
  bool _remoteUserJoined = false;
  int? _remoteUid;
  bool _muted = false;
  bool _speakerOn = true;
  bool _cameraOff = false;
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // Request permissions
    await [Permission.microphone, Permission.camera].request();

    // Create Agora engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Register event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() => _joined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _remoteUserJoined = true;
            _remoteUid = remoteUid;
          });
          _startTimer();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          setState(() {
            _remoteUserJoined = false;
            _remoteUid = null;
          });
          _stopTimer();
          // Auto leave when other user disconnects
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('Agora Error: $err - $msg');
        },
      ),
    );

    if (widget.isVideoCall) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.disableVideo();
    }

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );

    // Join channel (token null = testing mode, no token needed for sandbox)
    await _engine.joinChannel(
      token: '',
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String _formatDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _engine.muteLocalAudioStream(_muted);
  }

  void _toggleSpeaker() {
    setState(() => _speakerOn = !_speakerOn);
    _engine.setEnableSpeakerphone(_speakerOn);
  }

  void _toggleCamera() {
    setState(() => _cameraOff = !_cameraOff);
    _engine.muteLocalVideoStream(_cameraOff);
  }

  void _switchCamera() {
    _engine.switchCamera();
  }

  void _endCall() async {
    _stopTimer();
    await _engine.leaveChannel();
    await _engine.release();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cleanupAgora() async {
    try {
      await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      debugPrint("Agora Teardown Error: $e");
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _cleanupAgora();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Video / Audio Background ──
            if (widget.isVideoCall) ...[
              // Remote video (full screen)
              if (_remoteUserJoined && _remoteUid != null)
                AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine,
                    canvas: VideoCanvas(uid: _remoteUid!),
                    connection: RtcConnection(channelId: widget.channelName),
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAvatar(),
                      const SizedBox(height: 16),
                      Text(widget.otherUserName,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(_joined ? 'Menunggu jawaban...' : 'Menghubungkan...',
                          style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
              // Local video (PiP - small preview)
              if (_joined && !_cameraOff)
                Positioned(
                  top: 16,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 120,
                      height: 160,
                      child: AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      ),
                    ),
                  ),
                ),
            ] else ...[
              // Voice call UI
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAvatar(),
                    const SizedBox(height: 24),
                    Text(widget.otherUserName,
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_remoteUserJoined)
                      Text(_formatDuration(_seconds),
                          style: const TextStyle(color: RupiaColors.gold, fontSize: 18, fontWeight: FontWeight.w600))
                    else
                      Text(_joined ? 'Memanggil...' : 'Menghubungkan...',
                          style: const TextStyle(color: Colors.white54, fontSize: 16)),
                  ],
                ),
              ),
            ],

            // ── Top bar ──
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: _endCall,
              ),
            ),
            if (_remoteUserJoined && widget.isVideoCall)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_formatDuration(_seconds),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),

            // ── Bottom controls ──
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  _ControlButton(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    label: _muted ? 'Unmute' : 'Mute',
                    isActive: _muted,
                    onTap: _toggleMute,
                  ),
                  // Speaker (voice only)
                  if (!widget.isVideoCall)
                    _ControlButton(
                      icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                      label: 'Speaker',
                      isActive: !_speakerOn,
                      onTap: _toggleSpeaker,
                    ),
                  // Camera toggle (video only)
                  if (widget.isVideoCall)
                    _ControlButton(
                      icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                      label: 'Kamera',
                      isActive: _cameraOff,
                      onTap: _toggleCamera,
                    ),
                  // Flip camera (video only)
                  if (widget.isVideoCall)
                    _ControlButton(
                      icon: Icons.cameraswitch,
                      label: 'Putar',
                      onTap: _switchCamera,
                    ),
                  // End call
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final initials = widget.otherUserName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3C8F), Color(0xFF0D2060)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white24, width: 3),
      ),
      child: Center(
        child: Text(initials,
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.isActive = false,
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
              color: isActive ? Colors.white : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: isActive ? Colors.black87 : Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
