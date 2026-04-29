import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../utils/colors.dart';

// ── Ganti dengan App ID Agora Anda dari console.agora.io ──
const String agoraAppId = 'c10911c3802e494dbb69ac8fefb94d57';

class CallScreen extends StatefulWidget {
  final String channelName;
  final String otherUserName;
  final String otherUserId;
  final bool isVideoCall;
  final String? otherUserPhoto;
  // isIncoming = true berarti user ini MENERIMA panggilan (tidak perlu kirim FCM lagi)
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.channelName,
    required this.otherUserName,
    required this.otherUserId,
    required this.isVideoCall,
    this.otherUserPhoto,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  late RtcEngine _engine;
  bool _joined = false;
  bool _remoteUserJoined = false;
  int? _remoteUid;
  bool _muted = false;
  bool _speakerOn = true;
  bool _cameraOff = false;
  late bool _isVideoMode;
  Timer? _timer;
  int _seconds = 0;
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  bool _isEnding = false;
  bool _engineReady = false; // Prevent rendering before engine init
  Timer? _noAnswerTimer; // Timeout jika tidak diangkat

  // Animations
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // PiP drag position
  double _pipTop = 80;
  double _pipRight = 16;

  @override
  void initState() {
    super.initState();
    _isVideoMode = widget.isVideoCall;
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _initAgora();
  }

  /// ── PERUBAHAN UTAMA ──
  /// 1. Request token dari backend sebelum join
  /// 2. Kirim FCM ke receiver via /agora/call (hanya caller)
  /// 3. Gunakan user ID sebagai Agora UID
  /// 4. Timeout 60 detik jika tidak diangkat
  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    if (agoraAppId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Agora APP ID belum diisi'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    // Ambil auth token dan user ID dari SharedPreferences
    final authToken = await AuthService().currentToken;
    final currentUid = await AuthService().currentUid;

    if (authToken == null || currentUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Sesi login tidak ditemukan'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
      return;
    }

    // ── Step 1: Request Agora RTC token dari backend ──
    // Tanpa token, Agora akan menolak koneksi karena project pakai App Certificate
    String agoraToken = '';
    final agoraUid = int.tryParse(currentUid) ?? 0;

    try {
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      dio.options.headers['Authorization'] = 'Bearer $authToken';
      dio.options.headers['Accept'] = 'application/json';

      final tokenRes = await dio.post('/api/agora/token', data: {
        'channel_name': widget.channelName,
        'uid': currentUid,
      });

      agoraToken = tokenRes.data['token'] ?? '';
      debugPrint('✅ Agora token diterima: ${agoraToken.substring(0, 20)}...');
    } catch (e) {
      debugPrint('❌ Gagal request Agora token: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendapatkan token panggilan: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
      return;
    }

    // ── Step 2: Kirim FCM ke receiver (hanya jika CALLER, bukan penerima) ──
    // Ini agar HP tujuan menerima push notification "Panggilan Masuk"
    if (!widget.isIncoming) {
      try {
        final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
        dio.options.headers['Authorization'] = 'Bearer $authToken';
        dio.options.headers['Accept'] = 'application/json';

        await dio.post('/api/agora/call', data: {
          'receiver_id': widget.otherUserId,
          'channel_name': widget.channelName,
          'call_type': widget.isVideoCall ? 'video' : 'voice',
        });
        debugPrint('✅ FCM panggilan terkirim ke user ${widget.otherUserId}');
      } catch (e) {
        debugPrint('⚠️ Gagal kirim FCM panggilan: $e');
        // Lanjutkan saja, mungkin receiver bisa join manual
      }
    }

    // ── Step 3: Inisialisasi Agora Engine ──
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // PENTING: Set video config SEBELUM registerEventHandler
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );

    if (widget.isVideoCall) {
      await _engine.enableVideo();
      await _engine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 480),
          frameRate: 15,
          bitrate: 0, // auto
        ),
      );
      await _engine.startPreview();
    } else {
      await _engine.disableVideo();
    }

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('✅ Berhasil join channel: ${connection.channelId}');
          if (mounted) setState(() => _joined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('✅ Remote user joined: $remoteUid');
          if (mounted) {
            setState(() {
              _remoteUserJoined = true;
              _remoteUid = remoteUid;
            });
            // Panggilan diangkat — batalkan timeout
            _noAnswerTimer?.cancel();
            _pulseController.stop();
            _startTimer();
            _startHideControlsTimer();
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('📴 Remote user offline: $remoteUid, reason: $reason');
          if (mounted) {
            setState(() { _remoteUserJoined = false; _remoteUid = null; });
            _stopTimer();
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) Navigator.pop(context);
            });
          }
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('❌ Agora Error: $err - $msg');
        },
        onConnectionStateChanged: (RtcConnection c, ConnectionStateType s, ConnectionChangedReasonType r) {
          debugPrint('🔄 Agora State: $s, Reason: $r');
        },
      ),
    );

    if (mounted) setState(() => _engineReady = true);

    // ── Step 4: Join channel DENGAN token dan opsi video/audio ──
    await _engine.joinChannel(
      token: agoraToken,
      channelId: widget.channelName,
      uid: agoraUid,
      options: ChannelMediaOptions(
        publishCameraTrack: widget.isVideoCall,
        publishMicrophoneTrack: true,
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
      ),
    );

    // ── Step 5: Timeout 60 detik jika tidak ada yang angkat ──
    _noAnswerTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && !_remoteUserJoined) {
        debugPrint('⏰ Timeout — tidak ada yang angkat');
        _endCall();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _stopTimer() => _timer?.cancel();

  String _formatDuration(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
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

  void _switchCamera() => _engine.switchCamera();

  void _upgradeToVideo() async {
    await _engine.enableVideo();
    await _engine.startPreview();
    await _engine.updateChannelMediaOptions(
      const ChannelMediaOptions(
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        autoSubscribeVideo: true,
      ),
    );
    setState(() {
      _isVideoMode = true;
      _cameraOff = false;
    });
  }

  void _endCall() {
    if (_isEnding) return;
    _isEnding = true;
    _stopTimer();
    _noAnswerTimer?.cancel();

    // Pop layar LANGSUNG agar user tidak menunggu
    if (mounted) Navigator.pop(context);

    // Cleanup di background (tidak perlu ditunggu)
    _saveCallLog();
    try {
      _engine.leaveChannel();
      _engine.release();
    } catch (_) {}
  }

  Future<void> _saveCallLog() async {
    try {
      final token = await AuthService().currentToken;
      if (token == null) return;
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      dio.options.headers['Authorization'] = 'Bearer $token';
      dio.options.headers['Accept'] = 'application/json';
      await dio.post('/api/call-logs', data: {
        'receiver_id': widget.otherUserId,
        'channel_name': widget.channelName,
        'type': _isVideoMode ? 'video' : 'voice',
        'status': _remoteUserJoined ? 'answered' : 'missed',
        'duration': _seconds,
      });
    } catch (e) {
      debugPrint('SaveCallLog Error: $e');
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_isVideoMode && _remoteUserJoined) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _startHideControlsTimer();
  }

  @override
  void dispose() {
    _stopTimer();
    _noAnswerTimer?.cancel();
    _hideControlsTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    try { _engine.leaveChannel(); _engine.release(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: _isVideoMode ? _toggleControls : null,
          child: Stack(children: [
            // Background
            _buildBackground(),
            // Video views
            if (_isVideoMode && _engineReady) ..._buildVideoViews(),
            // Center content (voice call or waiting)
            if (!_isVideoMode || !_remoteUserJoined) _buildCenterContent(),
            // Top bar
            if (_controlsVisible) _buildTopBar(),
            // Bottom controls
            if (_controlsVisible) _buildBottomControls(),
          ]),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (_isVideoMode && _remoteUserJoined) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0A0E21), Color(0xFF1A1A3E), Color(0xFF0D2B6B)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(painter: _ParticlePainter(), size: Size.infinite),
    );
  }

  List<Widget> _buildVideoViews() {
    return [
      // Remote video full screen
      if (_remoteUserJoined && _remoteUid != null)
        Positioned.fill(
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(
                uid: _remoteUid!,
                renderMode: RenderModeType.renderModeHidden,
              ),
              connection: RtcConnection(channelId: widget.channelName),
            ),
          ),
        ),
      // Local PiP (draggable) — tampilkan juga saat menunggu (sebelum remote join)
      if (_joined && !_cameraOff)
        Positioned(
          top: _pipTop, right: _pipRight,
          child: GestureDetector(
            onPanUpdate: (d) {
              setState(() {
                _pipTop = (_pipTop + d.delta.dy).clamp(40, MediaQuery.of(context).size.height - 220);
                _pipRight = (_pipRight - d.delta.dx).clamp(8, MediaQuery.of(context).size.width - 130);
              });
            },
            child: Container(
              width: 110, height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white30, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 12)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(
                      uid: 0,
                      renderMode: RenderModeType.renderModeHidden,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildCenterContent() {
    final initials = widget.otherUserName.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    final hasPhoto = widget.otherUserPhoto != null && widget.otherUserPhoto!.isNotEmpty;

    return SafeArea(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Animated avatar with glow rings
          Stack(
            alignment: Alignment.center,
            children: [
              // Animated outer rings (only while calling)
              if (!_remoteUserJoined)
                ...List.generate(3, (i) {
                  return AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) {
                      final scale = 1.0 + (i + 1) * 0.12 * _pulseAnimation.value;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 130, height: 130,
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
              // Main avatar
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, child) {
                  final scale = _remoteUserJoined ? 1.0 : _pulseAnimation.value;
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasPhoto ? null : const LinearGradient(
                      colors: [Color(0xFF2557B3), Color(0xFF0D2060)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF2557B3).withOpacity(0.4), blurRadius: 30, spreadRadius: 5),
                    ],
                    image: hasPhoto ? DecorationImage(
                      image: NetworkImage(widget.otherUserPhoto!),
                      fit: BoxFit.cover,
                    ) : null,
                  ),
                  child: hasPhoto ? null : Center(child: Text(initials,
                      style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w700))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Name
          Text(widget.otherUserName,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          // Status
          if (_remoteUserJoined)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4ADE80))),
                const SizedBox(width: 8),
                Text(_formatDuration(_seconds),
                    style: const TextStyle(color: RupiaColors.gold, fontSize: 18, fontWeight: FontWeight.w600)),
              ]),
            )
          else
            _buildCallingStatus(),
          const SizedBox(height: 8),
          // Call type indicator
          Text(
            _isVideoMode ? '📹 Panggilan Video' : '📞 Panggilan Suara',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
          ),
        ]),
      ),
    );
  }

  Widget _buildCallingStatus() {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: 100),
      duration: const Duration(seconds: 100),
      builder: (_, val, __) {
        final dots = '.' * ((val % 3) + 1);
        final text = _joined ? 'Memanggil$dots' : 'Menghubungkan$dots';
        return Text(text, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16));
      },
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 8, right: 16, bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.6), Colors.transparent],
            ),
          ),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
              onPressed: _endCall,
            ),
            const Spacer(),
            if (_remoteUserJoined && _isVideoMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4ADE80),
                      boxShadow: [BoxShadow(color: const Color(0xFF4ADE80).withOpacity(0.5), blurRadius: 6)])),
                  const SizedBox(width: 8),
                  Text(_formatDuration(_seconds),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ]),
              ),
            const SizedBox(width: 8),
            if (!_isVideoMode)
              IconButton(
                icon: const Icon(Icons.videocam_rounded, color: Colors.white70, size: 26),
                tooltip: 'Upgrade ke Video',
                onPressed: _upgradeToVideo,
              ),
            if (_isVideoMode)
              IconButton(
                icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white70, size: 24),
                tooltip: 'Putar Kamera',
                onPressed: _switchCamera,
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20, right: 20, top: 16,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _GlassButton(
                icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: _muted ? 'Unmute' : 'Mute',
                isActive: _muted, onTap: _toggleMute,
              ),
              if (_isVideoMode)
                _GlassButton(
                  icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                  label: _cameraOff ? 'Kamera On' : 'Kamera Off',
                  isActive: _cameraOff, onTap: _toggleCamera,
                ),
              if (!_isVideoMode)
                _GlassButton(
                  icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  label: _speakerOn ? 'Speaker' : 'Earpiece',
                  isActive: !_speakerOn, onTap: _toggleSpeaker,
                ),
              if (!_isVideoMode && _joined)
                _GlassButton(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  onTap: _upgradeToVideo,
                ),
              if (_isVideoMode)
                _GlassButton(
                  icon: Icons.cameraswitch_rounded,
                  label: 'Putar', onTap: _switchCamera,
                ),
              // End call
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    ),
                  ),
                  child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Glassmorphism Button ──
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon, required this.label,
    this.isActive = false, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Icon(icon,
              color: isActive ? const Color(0xFFEF4444) : Colors.white, size: 22),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(
          color: Colors.white60, fontSize: 10)),
      ]),
    );
  }
}

// ── Subtle background particles ──
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
