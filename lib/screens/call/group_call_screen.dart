import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import '../../utils/colors.dart';

const String _agoraAppId = 'c10911c3802e494dbb69ac8fefb94d57';

class GroupCallScreen extends StatefulWidget {
  final String channelName;
  final String groupName;
  final bool isVideoCall;

  const GroupCallScreen({
    super.key,
    required this.channelName,
    required this.groupName,
    required this.isVideoCall,
  });

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen>
    with TickerProviderStateMixin {
  // FIXED: Nullable engine — mencegah LateInitializationError jika init gagal
  RtcEngine? _engine;
  bool _engineReady = false;
  bool _isEngineInitialized = false; // FIXED Bug #20: guard double-init
  bool _localJoined = false;
  bool _isVideoMode = false;
  bool _muted = false;
  bool _cameraOff = false;
  late bool _speakerOn;
  bool _isEnding = false;

  // Remote users — Agora assigns each a unique uid
  final Map<int, bool> _remoteUsers = {}; // uid -> hasVideo

  int _seconds = 0;
  Timer? _timer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _isVideoMode = widget.isVideoCall;
    _speakerOn = widget.isVideoCall;
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initAgora();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    // FIXED Bug #8: dispose() tidak bisa await. _endCall() (yang SUDAH await
    // _disposeEngine()) selalu dipanggil sebelum navigator pop.
    // Safety net: null-kan referensi segera, fire-and-forget cleanup.
    final engineRef = _engine;
    _engine = null;
    _engineReady = false;
    if (engineRef != null) {
      Future(() async {
        try { await engineRef.leaveChannel(); } catch (_) {}
        try { await engineRef.stopPreview(); } catch (_) {}
        try { await engineRef.release(); } catch (_) {}
      });
    }
    super.dispose();
  }

  Future<void> _disposeEngine() async {
    if (_engine == null) return;
    try { await _engine!.leaveChannel(); } catch (_) {}
    try { await _engine!.stopPreview(); } catch (_) {}
    try { await _engine!.release(); } catch (_) {}
    _engine = null;
    _engineReady = false;
    _isEngineInitialized = false;
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    // FIXED Bug #15: mounted check setelah async permission request
    if (!mounted) return;

    if (_agoraAppId.isEmpty || _agoraAppId == 'YOUR_AGORA_APP_ID') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Agora APP ID belum diisi'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
      return;
    }

    // ── Request auth token & uid ──
    final authToken = await AuthService().currentToken;
    final currentUid = await AuthService().currentUid;

    // FIXED Bug #15: mounted check setelah async auth request
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

    // ── Request Agora RTC token dari server ──
    final channelId = 'group_${widget.channelName}';
    final agoraUid = int.tryParse(currentUid) ?? 0;
    String agoraToken = '';

    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      dio.options.headers['Authorization'] = 'Bearer $authToken';
      dio.options.headers['Accept'] = 'application/json';

      final tokenRes = await dio.post('/api/agora/token', data: {
        'channel_name': channelId,
        'uid': currentUid,
      });

      if (!mounted) return;

      agoraToken = tokenRes.data['token'] ?? '';
      // FIXED Bug #14: Cek token kosong sebelum lanjut
      if (agoraToken.isEmpty) {
        debugPrint('❌ Token grup kosong dari server');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Token panggilan grup kosong'), backgroundColor: Colors.red),
          );
          Navigator.pop(context);
        }
        return;
      }
      // FIXED Bug #13: substring dengan clamp agar tidak crash jika token pendek
      debugPrint('✅ Agora group token diterima: ${agoraToken.substring(0, agoraToken.length.clamp(0, 20))}...');
    } catch (e) {
      debugPrint('❌ Gagal request Agora group token: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendapatkan token panggilan grup: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
      return;
    }

    if (!mounted) return;

    // ── Inisialisasi Agora Engine ──
    try {
      // FIXED Bug #20: guard double-init
      if (_isEngineInitialized) return;

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: _agoraAppId,
        // FIXED: channelProfileLiveBroadcasting agar clientRole Broadcaster aktif
        // channelProfileCommunication mengabaikan role setting → video bisa blank
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // Set Broadcaster agar semua peserta bisa publish audio & video
      // Tanpa ini di LiveBroadcasting profile, default = Audience (tidak publish)
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    } catch (e) {
      debugPrint('❌ Gagal inisialisasi Agora Group Engine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulai engine panggilan: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
      return;
    }

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        if (mounted) setState(() => _localJoined = true);
        _startTimer();
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint('✅ Group remote user joined: $remoteUid');
        if (mounted) {
          setState(() {
            // FIXED: Inisialisasi hasVideo=false, update lewat onRemoteVideoStateChanged
            _remoteUsers[remoteUid] = false;
          });
        }
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        if (mounted) {
          setState(() {
            _remoteUsers.remove(remoteUid);
          });
        }
      },
      onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid,
          RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
        debugPrint('📹 Group remote video uid=$remoteUid state=$state');
        if (mounted) {
          setState(() {
            // FIXED: Handle Starting + Decoding (dulu hanya Decoding — bisa terlewat)
            switch (state) {
              case RemoteVideoState.remoteVideoStateStarting:
              case RemoteVideoState.remoteVideoStateDecoding:
                _remoteUsers[remoteUid] = true;
                break;
              case RemoteVideoState.remoteVideoStateStopped:
              case RemoteVideoState.remoteVideoStateFailed:
                _remoteUsers[remoteUid] = false;
                break;
              default:
                break;
            }
          });
        }
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint('Agora Group Error: $err - $msg');
        // Handle token errors — tanpa ini group call diam-diam gagal
        if (err == ErrorCodeType.errInvalidToken || err == ErrorCodeType.errTokenExpired) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Token panggilan grup invalid/expired'), backgroundColor: Colors.red),
            );
            _endCall();
          }
        }
      },
      onConnectionStateChanged: (RtcConnection c, ConnectionStateType s, ConnectionChangedReasonType r) {
        debugPrint('🔄 Group Agora State: $s, Reason: $r');
        if (s == ConnectionStateType.connectionStateFailed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Koneksi panggilan grup gagal'), backgroundColor: Colors.red),
          );
          _endCall();
        }
      },
      // FIXED Bug #17: Handle token expiry agar panggilan grup panjang tidak putus
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
        debugPrint('⚠️ Group token akan expire — mencoba renew...');
        _renewGroupToken();
      },
    ));

    if (_isVideoMode) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.disableVideo();
    }

    await _engine!.setDefaultAudioRouteToSpeakerphone(_speakerOn);
    await _engine!.setEnableSpeakerphone(_speakerOn);

    _isEngineInitialized = true;
    if (!mounted) { await _disposeEngine(); return; }
    if (mounted) setState(() => _engineReady = true);

    // ── Join Channel (dengan try-catch agar tidak crash) ──
    try {
      await _engine!.joinChannel(
        token: agoraToken,
        channelId: channelId,
        uid: agoraUid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: _isVideoMode,
          publishMicrophoneTrack: true,
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
        ),
      );
      debugPrint('✅ Group joinChannel() — channel=$channelId uid=$agoraUid isVideo=$_isVideoMode');
    } catch (e) {
      debugPrint('❌ Group joinChannel() EXCEPTION: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal bergabung ke panggilan grup: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
      return;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String _formatTime(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void _toggleMute() {
    if (_engine == null || !_engineReady) return;
    setState(() => _muted = !_muted);
    _engine!.muteLocalAudioStream(_muted);
  }

  void _toggleSpeaker() {
    if (_engine == null || !_engineReady) return;
    setState(() => _speakerOn = !_speakerOn);
    _engine!.setEnableSpeakerphone(_speakerOn);
  }

  void _toggleCamera() {
    if (_engine == null || !_engineReady) return;
    setState(() => _cameraOff = !_cameraOff);
    _engine!.muteLocalVideoStream(_cameraOff);
  }

  void _switchCamera() { if (_engine != null && _engineReady) _engine!.switchCamera(); }

  void _upgradeToVideo() async {
    if (_engine == null || !_engineReady) return;
    await _engine!.enableVideo();
    await _engine!.startPreview();
    // FIXED: Update channel options saat upgrade ke video
    await _engine!.updateChannelMediaOptions(const ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      publishCameraTrack: true,
      publishMicrophoneTrack: true,
      autoSubscribeVideo: true,
      autoSubscribeAudio: true,
    ));
    setState(() {
      _isVideoMode = true;
      _cameraOff = false;
    });
  }

  void _endCall() async {
    if (_isEnding) return;
    _isEnding = true;
    _timer?.cancel();
    try { _pulseController.stop(); } catch (_) {}
    await _saveCallLog();
    await _disposeEngine();
    if (mounted) Navigator.pop(context);
  }

  /// FIXED Bug #17: Renew token saat hampir expire agar group call panjang tidak putus
  Future<void> _renewGroupToken() async {
    if (_engine == null || !_isEngineInitialized) return;
    try {
      final authToken = await AuthService().currentToken;
      final currentUid = await AuthService().currentUid;
      if (authToken == null || currentUid == null) return;

      final channelId = 'group_${widget.channelName}';
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      dio.options.headers['Authorization'] = 'Bearer $authToken';
      dio.options.headers['Accept'] = 'application/json';

      final tokenRes = await dio.post('/api/agora/token', data: {
        'channel_name': channelId,
        'uid': currentUid,
      });

      final newToken = tokenRes.data['token'] ?? '';
      if (newToken.isNotEmpty) {
        await _engine!.renewToken(newToken);
        debugPrint('✅ Group Agora token renewed successfully');
      }
    } catch (e) {
      debugPrint('⚠️ Gagal renew group Agora token: $e');
    }
  }

  Future<void> _saveCallLog() async {
    final channelId = 'group_${widget.channelName}';
    try {
      final token = await AuthService().currentToken;
      if (token == null) return;
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      dio.options.headers['Authorization'] = 'Bearer $token';
      dio.options.headers['Accept'] = 'application/json';
      await dio.post('/api/call-logs', data: {
        'group_id': widget.channelName,
        'group_name': widget.groupName,
        'channel_name': channelId, // Konsisten dengan channelId saat joinChannel
        'type': _isVideoMode ? 'video' : 'voice',
        'status': _remoteUsers.isNotEmpty ? 'answered' : 'missed',
        'duration': _seconds,
      });
      debugPrint('GroupCallLog saved successfully');
    } catch (e) {
      debugPrint('SaveGroupCallLog Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIXED Bug #16: PopScope mencegah iOS swipe-back tanpa cleanup
    return PopScope(
      canPop: _isEnding,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isEnding) {
          _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1A),
        body: Stack(
          children: [
            // Background
            _buildBackground(),
            // Content
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: _isVideoMode && _remoteUsers.isNotEmpty
                        ? _buildVideoGrid()
                        : _buildVoiceUI(),
                  ),
                  _buildControls(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0F1A), Color(0xFF0D2B6B), Color(0xFF0A0F1A)],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _endCall,
          ),
          Expanded(
            child: Column(
              children: [
                Text(widget.groupName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  _localJoined
                      ? '${_remoteUsers.length + 1} peserta · ${_formatTime(_seconds)}'
                      : 'Menghubungkan...',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!_isVideoMode)
            IconButton(
              icon: const Icon(Icons.videocam_rounded, color: Colors.white70),
              tooltip: 'Upgrade ke Video',
              onPressed: _upgradeToVideo,
            ),
          if (_isVideoMode)
            IconButton(
              icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white70),
              onPressed: _switchCamera,
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceUI() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Group icon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 100, height: 100,
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
          if (_remoteUsers.isEmpty)
            const Text('Menunggu peserta lain bergabung...',
                style: TextStyle(color: Colors.white54, fontSize: 14))
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: _remoteUsers.keys.map((uid) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Center(
                        child: Text('U$uid',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Peserta ${_remoteUsers.keys.toList().indexOf(uid) + 1}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    final participants = _remoteUsers.keys.toList();
    final totalParticipants = participants.length + 1; // +1 for local

    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: totalParticipants <= 2 ? 1 : 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: totalParticipants <= 2 ? 0.7 : 0.75,
        ),
        itemCount: totalParticipants,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Local user tile
            return _buildVideoTile(
              child: (_cameraOff || !_engineReady || _engine == null)
                  ? _buildAvatarPlaceholder('Anda')
                  : AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(
                          uid: 0, // FIXED: local = uid 0
                          renderMode: RenderModeType.renderModeHidden,
                        ),
                        // FIXED: Flutter texture lebih stabil cross-platform
                        useFlutterTexture: true,
                        useAndroidSurfaceView: false,
                      ),
                    ),
              label: 'Anda',
              isMuted: _muted,
            );
          }

          final remoteUid = participants[index - 1];
          // FIXED: Tampilkan AgoraVideoView segera setelah user join
          // Overlay avatar hanya jika video belum streaming (hasVideo=false)
          final hasVideo = _remoteUsers[remoteUid] ?? false;

          return _buildVideoTile(
            child: (_engine == null || !_engineReady)
                ? _buildAvatarPlaceholder('Peserta $index')
                : Stack(
                    children: [
                      // FIXED: Selalu render remote view — view akan blank sendiri
                      // jika stream belum datang, bukan crash
                      Positioned.fill(
                        child: AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: _engine!,
                            canvas: VideoCanvas(
                              uid: remoteUid, // FIXED: uid dari onUserJoined
                              renderMode: RenderModeType.renderModeHidden,
                            ),
                            connection: RtcConnection(channelId: 'group_${widget.channelName}'),
                            useFlutterTexture: true,  // FIXED
                            useAndroidSurfaceView: false,
                          ),
                        ),
                      ),
                      // Overlay avatar jika video belum aktif
                      if (!hasVideo)
                        Positioned.fill(child: _buildAvatarPlaceholder('Peserta $index')),
                    ],
                  ),
            label: 'Peserta $index',
            isMuted: false,
          );
        },
      ),
    );
  }

  Widget _buildVideoTile({required Widget child, required String label, required bool isMuted}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(child: child),
          // Name label
          Positioned(
            left: 8, bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  if (isMuted) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.mic_off, color: Colors.red, size: 14),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      color: const Color(0xFF1A2540),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
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
            icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _muted ? 'Unmute' : 'Mute',
            active: _muted,
            onTap: _toggleMute,
          ),
          if (_isVideoMode)
            _buildControlBtn(
              icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
              label: _cameraOff ? 'Kamera On' : 'Kamera Off',
              active: _cameraOff,
              onTap: _toggleCamera,
            ),
          _buildControlBtn(
            icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
            label: _speakerOn ? 'Speaker' : 'Earpiece',
            active: _speakerOn,
            onTap: _toggleSpeaker,
          ),
          // End call button
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
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.08),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Icon(icon, color: active ? const Color(0xFFEF4444) : Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}
