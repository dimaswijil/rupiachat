import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import '../../utils/colors.dart';

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
  RtcEngine? _engine;
  bool _isEngineInitialized = false;
  bool _joined = false;
  bool _remoteUserJoined = false;
  // FIXED: Hapus _remoteVideoReady sebagai gate render — cukup cek _remoteUid != null
  // Dulu: remote video tidak pernah tampil jika onRemoteVideoStateChanged tidak ter-fire
  bool _remoteVideoActive = false;   // true = video sedang stream (bukan frozen/stopped)
  bool _isRemoteVideoFrozen = false;
  int? _remoteUid;
  bool _muted = false;
  late bool _speakerOn;
  bool _cameraOff = false;
  late bool _isVideoMode;
  Timer? _timer;
  int _seconds = 0;
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  bool _isEnding = false;
  bool _engineReady = false; // Prevent rendering before engine init
  Timer? _noAnswerTimer; // Timeout jika tidak diangkat
  final AudioPlayer _ringbackPlayer = AudioPlayer();

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
    _speakerOn = widget.isVideoCall;
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

    if (!widget.isIncoming) {
      _playRingbackTone();
    }

  }

  Future<void> _initAgora() async {
    // Request semua permission yang dibutuhkan (sesuai Agora official docs)
    await [Permission.microphone, Permission.camera, Permission.bluetooth, Permission.bluetoothConnect].request();

    if (!mounted) return;

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

    final authToken = await AuthService().currentToken;
    final currentUid = await AuthService().currentUid;

    if (!mounted) return;

    if (authToken == null || currentUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Sesi login tidak ditemukan'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
      return;
    }

    String agoraToken = '';
    const int agoraUid = 0;

    // ── 1. Request Agora token dari backend ──
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      dio.options.headers['Authorization'] = 'Bearer $authToken';
      dio.options.headers['Accept'] = 'application/json';

      final tokenRes = await dio.post('/api/agora/token', data: {
        'channel_name': widget.channelName,
        'uid': '0',
      });

      if (!mounted) return;

      agoraToken = tokenRes.data['token'] ?? '';
      if (agoraToken.isEmpty) {
        debugPrint('❌ Token kosong dari server');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Token panggilan kosong'), backgroundColor: Colors.red),
          );
          Navigator.pop(context);
        }
        return;
      }
      debugPrint('✅ Agora token diterima: ${agoraToken.substring(0, agoraToken.length.clamp(0, 20))}...');
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

    // ── 2. Kirim FCM ke penerima (hanya jika caller) ──
    if (!widget.isIncoming) {
      try {
        final dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ));
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
        // Lanjut saja — caller tetap bisa join channel
      }
    }

    if (!mounted) return;

    // ── 3. Inisialisasi Agora Engine ──
    try {
      if (_isEngineInitialized) return;
      
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: agoraAppId,
        // FIXED: channelProfileLiveBroadcasting agar clientRole Broadcaster aktif
        // channelProfileCommunication mengabaikan role setting → video bisa blank
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // FIXED: Set client role sebagai Broadcaster agar bisa publish audio & video
      // Tanpa ini, Agora v6 bisa default ke Audience yang tidak publish stream
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    } catch (e) {
      debugPrint('❌ Gagal inisialisasi Agora Engine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulai engine panggilan: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
      return;
    }

    if (!mounted) {
      await _disposeAgora();
      return;
    }

    // ── 4. Register event handler SEBELUM join ──
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('✅ Berhasil join channel: ${connection.channelId}, localUid: ${connection.localUid}, elapsed: ${elapsed}ms');
          if (mounted) setState(() => _joined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('✅ Remote user joined: $remoteUid');
          if (mounted) {
            setState(() {
              _remoteUserJoined = true;
              _remoteUid = remoteUid;
            });
            _ringbackPlayer.stop();
            _noAnswerTimer?.cancel();
            try { _pulseController.stop(); } catch (_) {}
            _startTimer();
            _startHideControlsTimer();
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('📴 Remote user offline: $remoteUid, reason: $reason');
          if (mounted) {
            setState(() { 
              _remoteUserJoined = false; 
              _remoteVideoActive = false; // FIXED: renamed from _remoteVideoReady
              _remoteUid = null; 
            });
            _stopTimer();
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && !_isEnding) _endCall();
            });
          }
        },
        onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
          debugPrint('📹 Remote video state uid=$remoteUid: $state, reason: $reason');
          if (mounted) {
            setState(() {
              // FIXED: Logika state video yang lebih robust
              // Dulu: hanya Starting/Decoding yang set ready — jika langsung Decoding bisa terlewat
              switch (state) {
                case RemoteVideoState.remoteVideoStateStarting:
                case RemoteVideoState.remoteVideoStateDecoding:
                  _remoteVideoActive = true;
                  _isRemoteVideoFrozen = false;
                  break;
                case RemoteVideoState.remoteVideoStateFrozen:
                  _isRemoteVideoFrozen = true;
                  // Tetap _remoteVideoActive = true agar view tidak hilang
                  break;
                case RemoteVideoState.remoteVideoStateStopped:
                case RemoteVideoState.remoteVideoStateFailed:
                  _remoteVideoActive = false;
                  _isRemoteVideoFrozen = false;
                  break;
                default:
                  break;
              }
            });
          }
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('❌ Agora Error: $err - $msg');
          // Jika error fatal, beri tahu user
          if (err == ErrorCodeType.errInvalidToken || err == ErrorCodeType.errTokenExpired) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Token panggilan invalid/expired'), backgroundColor: Colors.red),
              );
              _endCall();
            }
          }
        },
        onConnectionStateChanged: (RtcConnection c, ConnectionStateType s, ConnectionChangedReasonType r) {
          debugPrint('🔄 Agora State: $s, Reason: $r');
          if (s == ConnectionStateType.connectionStateFailed && mounted) {
            debugPrint('❌ Koneksi Agora gagal total');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Koneksi panggilan gagal'), backgroundColor: Colors.red),
            );
            _endCall();
          }
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('⚠️ Token akan expire — mencoba renew...');
          _renewAgoraToken();
        },
      ),
    );

    // ── 5. Konfigurasi audio & video ──
    try {
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: widget.isVideoCall
            ? AudioScenarioType.audioScenarioDefault
            : AudioScenarioType.audioScenarioChatroom,
      );

      if (widget.isVideoCall) {
        await _engine!.enableVideo();
        await _engine!.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 640, height: 480),
            frameRate: 15,
            bitrate: 0,
          ),
        );
        await _engine!.startPreview();
      } else {
        await _engine!.disableVideo();
      }

      await _engine!.setDefaultAudioRouteToSpeakerphone(_speakerOn);
      await _engine!.setEnableSpeakerphone(_speakerOn);
    } catch (e) {
      debugPrint('⚠️ Error konfigurasi audio/video: $e');
    }

    _isEngineInitialized = true;
    if (!mounted) {
      await _disposeAgora();
      return;
    }

    if (mounted) setState(() => _engineReady = true);

    // ── 6. Join Channel ──
    debugPrint('🎯 === JOINING AGORA CHANNEL ===');
    debugPrint('🎯 App ID: $agoraAppId');
    debugPrint('🎯 Channel: ${widget.channelName}');
    debugPrint('🎯 UID: $agoraUid');
    debugPrint('🎯 Token prefix: ${agoraToken.substring(0, agoraToken.length.clamp(0, 10))}...');
    debugPrint('🎯 Is Video: ${widget.isVideoCall}');

    try {
      if (!_joined) {
        // FIXED: Jangan set _joined=true sebelum await — biarkan onJoinChannelSuccess yang set
        // Ini mencegah state tidak konsisten jika joinChannel gagal silently
        await _engine!.joinChannel(
          token: agoraToken,
          channelId: widget.channelName,
          uid: agoraUid,
          // clientRoleBroadcaster wajib agar bisa publish audio & video
          options: ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishCameraTrack: widget.isVideoCall,
            publishMicrophoneTrack: true,
            autoSubscribeVideo: true,
            autoSubscribeAudio: true,
          ),
        );
        debugPrint('✅ joinChannel() berhasil — isVideo: ${widget.isVideoCall}');
      }
    } catch (e) {
      debugPrint('❌ joinChannel() EXCEPTION: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal bergabung ke panggilan: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
      return;
    }

    _noAnswerTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && !_remoteUserJoined) {
        debugPrint('⏰ Timeout — tidak ada yang angkat');
        _endCall();
      }
    });
  }

  /// Request token baru dari backend dan renew di engine
  /// Dipanggil oleh onTokenPrivilegeWillExpire agar panggilan tidak putus
  Future<void> _renewAgoraToken() async {
    if (_engine == null || !_isEngineInitialized) return;
    try {
      final authToken = await AuthService().currentToken;
      if (authToken == null) return;

      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      dio.options.headers['Authorization'] = 'Bearer $authToken';
      dio.options.headers['Accept'] = 'application/json';

      final tokenRes = await dio.post('/api/agora/token', data: {
        'channel_name': widget.channelName,
        'uid': '0',
      });

      final newToken = tokenRes.data['token'] ?? '';
      if (newToken.isNotEmpty) {
        await _engine!.renewToken(newToken);
        debugPrint('✅ Agora token renewed successfully');
      }
    } catch (e) {
      debugPrint('⚠️ Gagal renew Agora token: $e');
    }
  }

  void _playRingbackTone() async {
    await _ringbackPlayer.setReleaseMode(ReleaseMode.loop);
    await _ringbackPlayer.play(AssetSource('audio/ringback.wav'));
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
    if (_engine == null || !_isEngineInitialized) return;
    setState(() => _muted = !_muted);
    _engine!.muteLocalAudioStream(_muted);
  }

  void _toggleSpeaker() {
    if (_engine == null || !_isEngineInitialized) return;
    setState(() => _speakerOn = !_speakerOn);
    _engine!.setEnableSpeakerphone(_speakerOn);
  }

  void _toggleCamera() {
    if (_engine == null || !_isEngineInitialized) return;
    setState(() => _cameraOff = !_cameraOff);
    _engine!.muteLocalVideoStream(_cameraOff);
  }

  void _switchCamera() {
    if (_engine == null || !_isEngineInitialized) return;
    _engine!.switchCamera();
  }

  void _upgradeToVideo() async {
    if (_engine == null || !_isEngineInitialized) return;
    await _engine!.enableVideo();
    await _engine!.startPreview();
    // FIXED: Tambah clientRoleType saat upgrade ke video agar publish camera track
    await _engine!.updateChannelMediaOptions(
      const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
      ),
    );
    setState(() {
      _isVideoMode = true;
      _cameraOff = false;
    });
  }

  void _endCall() async {
    if (_isEnding) return;
    _isEnding = true;
    _ringbackPlayer.stop();
    _stopTimer();
    _noAnswerTimer?.cancel();
    _hideControlsTimer?.cancel();
    try { _pulseController.stop(); } catch (_) {}

    await _saveCallLog();

    // FIXED Bug #18: Fire-and-forget cancel signal agar tidak blokir end call
    // Sebelumnya await bisa menunggu hingga 15 detik jika backend lambat
    if (!widget.isIncoming && !_remoteUserJoined) {
      _sendCancelSignal(); // intentionally not awaited
    }

    await _disposeAgora();

    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendCancelSignal() async {
    try {
      final authToken = await AuthService().currentToken;
      if (authToken == null) return;
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      dio.options.headers['Authorization'] = 'Bearer $authToken';
      dio.options.headers['Accept'] = 'application/json';
      await dio.post('/api/agora/signal', data: {
        'target_id': widget.otherUserId,
        'channel_name': widget.channelName,
        'signal_type': 'cancel',
      });
    } catch (e) {
      debugPrint('SendCancelSignal Error: $e');
    }
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

  Future<void> _disposeAgora() async {
    if (_engine == null) return;
    
    if (_joined) {
      try { await _engine!.leaveChannel(); } catch (_) {}
      _joined = false;
    }
    
    try { await _engine!.stopPreview(); } catch (_) {}
    try { await _engine!.release(); } catch (_) {}
    _engine = null;
    _isEngineInitialized = false;
    _engineReady = false;
  }

  @override
  void dispose() {
    _stopTimer();
    _noAnswerTimer?.cancel();
    _hideControlsTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    // FIXED Bug #5: dispose() tidak bisa await, tapi _endCall() (yang SUDAH await
    // _disposeAgora()) selalu dipanggil sebelum navigator pop.
    // Di sini kita tangkap referensi engine lalu null-kan segera agar UI tidak akses,
    // kemudian fire-and-forget cleanup yang sebenarnya.
    final engineRef = _engine;
    _engine = null;
    _isEngineInitialized = false;
    _engineReady = false;
    if (engineRef != null) {
      // Fire-and-forget — aman karena engine sudah di-null dari state
      Future(() async {
        try { await engineRef.leaveChannel(); } catch (_) {}
        try { await engineRef.stopPreview(); } catch (_) {}
        try { await engineRef.release(); } catch (_) {}
      });
    }
    _ringbackPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isEnding,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isEnding) {
          _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _isVideoMode ? _toggleControls : null,
            child: Stack(children: [
              _buildBackground(),
              if (_isVideoMode && _engineReady) ..._buildVideoViews(),
              if (!_isVideoMode || !_remoteUserJoined) _buildCenterContent(),
              if (_controlsVisible) _buildTopBar(),
              if (_controlsVisible) _buildBottomControls(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (_isVideoMode && (_remoteUserJoined || !_cameraOff)) return const SizedBox.shrink();
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
    if (_engine == null || !_isEngineInitialized) return [];

    if (!_remoteUserJoined) {
      if (_cameraOff) return [];
      return [
        Positioned.fill(
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _engine!,
              canvas: const VideoCanvas(
                uid: 0, // FIXED: uid=0 = local user
                renderMode: RenderModeType.renderModeHidden,
              ),
              // FIXED: useFlutterTexture=true lebih stabil di iOS & Android
              // useAndroidSurfaceView menyebabkan blank di beberapa device
              useFlutterTexture: true,
              useAndroidSurfaceView: false,
            ),
          ),
        ),
        Positioned.fill(
          child: Container(color: Colors.black54),
        ),
      ];
    }

    return [
      // FIXED: Remote video — tampilkan segera setelah remoteUid tersedia
      // Dulu: hanya render jika _remoteVideoReady=true, tapi event bisa terlambat/tidak ter-fire
      // Sekarang: render view segera, overlay indikator jika belum active
      if (_remoteUid != null)
        Positioned.fill(
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine!,
              canvas: VideoCanvas(
                uid: _remoteUid!, // FIXED: uid dari onUserJoined — bukan 0
                renderMode: RenderModeType.renderModeHidden,
              ),
              connection: RtcConnection(channelId: widget.channelName),
              // FIXED: Flutter texture lebih stabil cross-platform
              useFlutterTexture: true,
              useAndroidSurfaceView: false,
            ),
          ),
        ),
      // Overlay: frozen indicator
      if (_isRemoteVideoFrozen)
        Positioned.fill(
          child: Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white70),
                  SizedBox(height: 16),
                  Text('Koneksi lemah...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        )
      // Overlay: menunggu video stream (sebelum _remoteVideoActive)
      else if (_remoteUid != null && !_remoteVideoActive)
        Positioned.fill(
          child: Container(
            color: const Color(0xFF0A0E21),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4ADE80)),
                  SizedBox(height: 16),
                  Text('Menunggu video...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      // PiP: local camera (draggable)
      if (!_cameraOff)
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
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(
                      uid: 0, // FIXED: local = uid 0
                      renderMode: RenderModeType.renderModeHidden,
                    ),
                    useFlutterTexture: true,  // FIXED: texture lebih stabil
                    useAndroidSurfaceView: false,
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
          Stack(
            alignment: Alignment.center,
            children: [
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
          Text(widget.otherUserName,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 10),
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
    // Kumpulkan semua tombol kontrol (tanpa End Call)
    final List<Widget> controlButtons = [
      _GlassButton(
        icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
        label: _muted ? 'Unmute' : 'Mute',
        isActive: _muted,
        onTap: _toggleMute,
      ),
      if (!_isVideoMode)
        _GlassButton(
          icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
          label: _speakerOn ? 'Speaker' : 'Earpiece',
          isActive: _speakerOn,
          onTap: _toggleSpeaker,
        ),
      if (_isVideoMode)
        _GlassButton(
          icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
          label: 'Kamera',
          isActive: _cameraOff,
          onTap: _toggleCamera,
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
          label: 'Putar',
          onTap: _switchCamera,
        ),
    ];

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 24, right: 24, top: 16,
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
                // Tombol kontrol (Mute, Speaker/Camera, Video/Switch)
                ...controlButtons,
                // End Call — sama rata dengan tombol lain
                _GlassButton(
                  icon: Icons.call_end_rounded,
                  label: 'Tutup',
                  isEndCall: true,
                  onTap: _endCall,
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
    required this.icon, required this.label,
    this.isActive = false, this.isEndCall = false, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // End Call → merah gradient, lainnya → glass transparan
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
          child: Icon(icon,
              color: isEndCall
                  ? Colors.white
                  : isActive ? const Color(0xFFEF4444) : Colors.white,
              size: 24),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
          color: isEndCall ? const Color(0xFFEF4444) : Colors.white60,
          fontSize: 10,
          fontWeight: isEndCall ? FontWeight.w600 : FontWeight.w400,
        )),
      ]),
    );
  }
}

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
