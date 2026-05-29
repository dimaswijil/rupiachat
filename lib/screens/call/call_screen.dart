import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/call_api_service.dart';
import 'controllers/agora_call_controller.dart';
import 'widgets/personal/video_call_view.dart';
import 'widgets/personal/call_background.dart';
import 'widgets/personal/call_center_profile.dart';
import 'widgets/personal/call_controls.dart';

class CallScreen extends StatefulWidget {
  final String channelName;
  final String otherUserName;
  final String otherUserId;
  final bool isVideoCall;
  final String? otherUserPhoto;
  // isIncoming = true berarti user ini MENERIMA panggilan
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
  late final AgoraCallController _controller;
  final CallApiService _apiService = CallApiService();

  Timer? _timer;
  final ValueNotifier<int> _seconds = ValueNotifier(0);
  final ValueNotifier<bool> _controlsVisible = ValueNotifier(true);
  Timer? _hideControlsTimer;
  bool _isEnding = false;
  Timer? _noAnswerTimer; // Timeout jika tidak diangkat
  final AudioPlayer _ringbackPlayer = AudioPlayer();

  // Animations
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    // Inisialisasi pengontrol panggilan Agora
    _controller = AgoraCallController(
      isVideoCall: widget.isVideoCall,
      onRemoteJoined: () {
        if (mounted) {
          _ringbackPlayer.stop();
          _noAnswerTimer?.cancel();
          try {
            _pulseController.stop();
          } catch (_) {}
          _startTimer();
          _startHideControlsTimer();
        }
      },
      onCallEnded: () {
        if (mounted && !_isEnding) _endCall();
      },
    );

    // Registrasi controller aktif global untuk handshake asinkronus
    AgoraCallController.activeController = _controller;

    // Daftarkan callback interaksi UI
    _controller.onShowMessage = (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFF0D2B6B),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };



    _controller.addListener(_onControllerChanged);
    _controller.initAgora(
      channelName: widget.channelName,
      otherUserId: widget.otherUserId,
      isIncoming: widget.isIncoming,
    );

    if (!widget.isIncoming) {
      _playRingbackTone();
    }

    _noAnswerTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && !_controller.remoteUserJoined) {
        debugPrint('⏰ Timeout — tidak ada yang angkat');
        _endCall();
      }
    });
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _playRingbackTone() async {
    await _ringbackPlayer.setReleaseMode(ReleaseMode.loop);
    await _ringbackPlayer.play(AssetSource('audio/ringback.wav'));
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _seconds.value++;
    });
  }

  void _stopTimer() => _timer?.cancel();

  void _endCall() async {
    if (_isEnding) return;
    _isEnding = true;
    _ringbackPlayer.stop();
    _stopTimer();
    _noAnswerTimer?.cancel();
    _hideControlsTimer?.cancel();
    try {
      _pulseController.stop();
    } catch (_) {}

    // Simpan log panggilan ke database via CallApiService
    await _apiService.saveCallLog(
      otherUserId: widget.otherUserId,
      channelName: widget.channelName,
      isVideoMode: _controller.isVideoMode,
      remoteUserJoined: _controller.remoteUserJoined,
      durationSeconds: _seconds.value,
    );

    // Kirim sinyal pembatalan ke lawan bicara jika tidak diangkat (caller) via CallApiService
    if (!widget.isIncoming && !_controller.remoteUserJoined) {
      _apiService.sendCallSignal(
        targetId: widget.otherUserId,
        channelName: widget.channelName,
        signalType: 'cancel',
      ); // intentionally not awaited (fire-and-forget)
    }

    await _controller.disposeEngine();

    if (mounted) Navigator.pop(context);
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_controller.isVideoMode && _controller.remoteUserJoined) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) _controlsVisible.value = false;
      });
    }
  }

  void _toggleControls() {
    _controlsVisible.value = !_controlsVisible.value;
    if (_controlsVisible.value) _startHideControlsTimer();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    
    // Bersihkan registry activeController secara aman
    if (AgoraCallController.activeController == _controller) {
      AgoraCallController.activeController = null;
    }

    _stopTimer();
    _noAnswerTimer?.cancel();
    _hideControlsTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    _seconds.dispose();
    _controlsVisible.dispose();
    _controller.disposeEngine();
    _ringbackPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isEnding,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isEnding) _endCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _controller.isVideoMode ? _toggleControls : null,
            onDoubleTap: _controller.isVideoMode ? _controller.switchCamera : null,
            child: Stack(children: [
              // Layer 1: Background
              CallBackground(
                isVideoMode: _controller.isVideoMode,
                engineReady: _controller.engineReady,
              ),

              // Layer 2: Video views
              if (_controller.isVideoMode && _controller.engineReady && _controller.engine != null)
                Positioned.fill(
                  child: VideoCallView(
                    engine: _controller.engine!,
                    channelName: widget.channelName,
                    remoteUid: _controller.remoteUid,
                    remoteUserJoined: _controller.remoteUserJoined,
                    cameraOff: _controller.cameraOff,
                    isRemoteVideoFrozen: _controller.isRemoteVideoFrozen,
                    localUid: _controller.localUid,
                    isFrontCamera: _controller.isFrontCamera,
                  ),
                ),

              // Layer 3: Center content
              if (!_controller.isVideoMode || !_controller.engineReady)
                ValueListenableBuilder<int>(
                  valueListenable: _seconds,
                  builder: (context, sec, _) {
                    return CallCenterProfile(
                      otherUserName: widget.otherUserName,
                      otherUserPhoto: widget.otherUserPhoto,
                      isVideoMode: _controller.isVideoMode,
                      joined: _controller.joined,
                      remoteUserJoined: _controller.remoteUserJoined,
                      seconds: sec,
                      pulseAnimation: _pulseAnimation,
                    );
                  },
                )
              else if (_controller.isVideoMode && _controller.engineReady && !_controller.remoteUserJoined)
                // Saat nunggu remote join — tampilkan avatar transparan
                Positioned.fill(
                  child: Container(
                    color: Colors.transparent,
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            widget.otherUserName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Memanggil...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ),

              // Layer 4 & 5: Controls — isolated dari video rebuild
              ValueListenableBuilder<bool>(
                valueListenable: _controlsVisible,
                builder: (context, visible, _) {
                  return AnimatedOpacity(
                    opacity: visible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !visible,
                      child: ValueListenableBuilder<int>(
                        valueListenable: _seconds,
                        builder: (context, sec, _) {
                          return CallControls(
                            isVideoMode: _controller.isVideoMode,
                            muted: _controller.muted,
                            speakerOn: _controller.speakerOn,
                            cameraOff: _controller.cameraOff,
                            joined: _controller.joined,
                            remoteUserJoined: _controller.remoteUserJoined,
                            controlsVisible: visible,
                            seconds: sec,
                            onMute: _controller.toggleMute,
                            onSpeaker: _controller.toggleSpeaker,
                            onCamera: _controller.toggleCamera,
                            onSwitchCamera: _controller.switchCamera,
                            onUpgradeToVideo: () => _controller.requestVideoUpgrade(
                              widget.otherUserId,
                              widget.channelName,
                            ),
                            onEndCall: _endCall,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
