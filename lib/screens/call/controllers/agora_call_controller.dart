import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../../../services/call_api_service.dart';

// App ID Agora dari console.agora.io
const String agoraAppId = 'c10911c3802e494dbb69ac8fefb94d57';

class AgoraCallController extends ChangeNotifier {
  static Future<void>? _activeReleaseFuture;
  static AgoraCallController? activeController;

  RtcEngine? _engine;
  bool _isEngineInitialized = false;
  bool _joined = false;
  bool _remoteUserJoined = false;
  bool _isRemoteVideoFrozen = false;
  int? _remoteUid;
  int? _localUid;
  bool _muted = false;
  bool _speakerOn;
  bool _cameraOff = false;
  bool _isVideoMode;
  bool _engineReady = false;
  bool _isWaitingVideoUpgrade = false;
  bool _isFrontCamera = true;

  // Callbacks untuk komunikasi dengan UI
  VoidCallback? onRemoteJoined;
  VoidCallback? onCallEnded;
  Function(String message)? onShowMessage;

  // Getter untuk mengekspos state ke UI
  RtcEngine? get engine => _engine;
  bool get joined => _joined;
  bool get remoteUserJoined => _remoteUserJoined;
  bool get isRemoteVideoFrozen => _isRemoteVideoFrozen;
  int? get remoteUid => _remoteUid;
  int? get localUid => _localUid;
  bool get muted => _muted;
  bool get speakerOn => _speakerOn;
  bool get cameraOff => _cameraOff;
  bool get isVideoMode => _isVideoMode;
  bool get engineReady => _engineReady;
  bool get isWaitingVideoUpgrade => _isWaitingVideoUpgrade;
  bool get isFrontCamera => _isFrontCamera;

  AgoraCallController({
    required bool isVideoCall,
    this.onRemoteJoined,
    this.onCallEnded,
  })  : _isVideoMode = isVideoCall,
        _speakerOn = isVideoCall;

  /// Inisialisasi Agora Engine, konfigurasi permission, API call token, dan join channel
  Future<void> initAgora({
    required String channelName,
    required String otherUserId,
    required bool isIncoming,
  }) async {
    // 1. Request permission kamera & mikrofon
    final permissions = <Permission>[
      Permission.microphone,
      Permission.camera,
    ];
    if (Platform.isAndroid) {
      permissions.add(Permission.bluetooth);
      permissions.add(Permission.bluetoothConnect);
    }
    final statuses = await permissions.request();

    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;

    if (!micGranted || (_isVideoMode && !cameraGranted)) {
      debugPrint('⚠️ Peringatan: Perekam suara atau Kamera tidak diizinkan.');
    }

    // 2. Await pelepasan engine lama jika ada
    if (_activeReleaseFuture != null) {
      debugPrint('⏳ Menunggu engine sebelumnya selesai release...');
      try {
        await _activeReleaseFuture;
      } catch (e) {
        debugPrint('⚠️ Error saat menunggu release engine lama: $e');
      }
      _activeReleaseFuture = null;
      debugPrint('✅ Engine sebelumnya selesai release');
    }

    if (agoraAppId.isEmpty) {
      debugPrint('⚠️ Agora APP ID belum diisi');
      onCallEnded?.call();
      return;
    }

    String agoraToken = '';
    final apiService = CallApiService();

    // 3. Request Agora token dari backend rupiachat
    try {
      agoraToken = await apiService.fetchAgoraToken(channelName);
      if (agoraToken.isEmpty) {
        debugPrint('❌ Token kosong dari server');
        onCallEnded?.call();
        return;
      }
      debugPrint('✅ Agora token diterima: ${agoraToken.substring(0, agoraToken.length.clamp(0, 20))}...');
    } catch (e) {
      debugPrint('❌ Gagal request Agora token: $e');
      onCallEnded?.call();
      return;
    }

    // 4. Kirim FCM ke penerima jika bertindak sebagai caller
    if (!isIncoming) {
      try {
        await apiService.sendCallFcm(
          receiverId: otherUserId,
          channelName: channelName,
          isVideoCall: _isVideoMode,
        );
        debugPrint('✅ FCM panggilan terkirim ke user $otherUserId');
      } catch (e) {
        debugPrint('⚠️ Gagal kirim FCM panggilan: $e');
      }
    }

    // 5. Inisialisasi Agora Engine
    try {
      if (_isEngineInitialized) return;

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    } catch (e) {
      debugPrint('❌ Gagal inisialisasi Agora Engine: $e');
      onCallEnded?.call();
      return;
    }

    // 6. Daftarkan event handler
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('✅ Berhasil join channel: ${connection.channelId}, localUid: ${connection.localUid}');
          _joined = true;
          _localUid = connection.localUid;
          notifyListeners();


        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('✅ Remote user joined: $remoteUid');
          _remoteUserJoined = true;
          _remoteUid = remoteUid;
          onRemoteJoined?.call();
          notifyListeners();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('📴 Remote user offline: $remoteUid, reason: $reason');
          _remoteUserJoined = false;
          notifyListeners();
          
          // Null-kan remoteUid di frame berikutnya
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _remoteUid = null;
            notifyListeners();
          });

          Future.delayed(const Duration(seconds: 2), () {
            onCallEnded?.call();
          });
        },
        onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
          debugPrint('📹 Remote video state uid=$remoteUid: $state, reason: $reason');
          switch (state) {
            case RemoteVideoState.remoteVideoStateStarting:
            case RemoteVideoState.remoteVideoStateDecoding:
              _isRemoteVideoFrozen = false;
              break;
            case RemoteVideoState.remoteVideoStateFrozen:
              _isRemoteVideoFrozen = true;
              break;
            case RemoteVideoState.remoteVideoStateStopped:
            case RemoteVideoState.remoteVideoStateFailed:
              _isRemoteVideoFrozen = false;
              break;
            default:
              break;
          }
          notifyListeners();
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('❌ Agora Error: $err - $msg');
          if (err == ErrorCodeType.errInvalidToken || err == ErrorCodeType.errTokenExpired) {
            onCallEnded?.call();
          }
        },
        onConnectionStateChanged: (RtcConnection c, ConnectionStateType s, ConnectionChangedReasonType r) {
          debugPrint('🔄 Agora State: $s, Reason: $r');
          if (s == ConnectionStateType.connectionStateFailed) {
            debugPrint('❌ Koneksi Agora gagal total');
            onCallEnded?.call();
          }
        },
        onLocalVideoStateChanged: (VideoSourceType source, LocalVideoStreamState state, LocalVideoStreamReason reason) {
          debugPrint('🎥 Kamera: $state — $reason');
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('⚠️ Token akan expire — mencoba renew...');
          renewToken(channelName);
        },
      ),
    );

    // 7. Konfigurasi audio profil & default routing
    try {
      await _engine!.enableAudio();
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: _isVideoMode
            ? AudioScenarioType.audioScenarioDefault
            : AudioScenarioType.audioScenarioChatroom,
      );
    } catch (e) {
      debugPrint('⚠️ setAudioProfile error: $e');
    }

    try {
      await _engine!.setDefaultAudioRouteToSpeakerphone(_speakerOn);
    } catch (e) {
      debugPrint('⚠️ setDefaultAudioRouteToSpeakerphone error: $e');
    }

    // 8. Konfigurasi video
    try {
      if (_isVideoMode) {
        await _engine!.enableVideo();
        await _engine!.enableLocalVideo(true);
        await _engine!.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 640, height: 480),
            frameRate: 15,
            bitrate: 0,
            orientationMode: OrientationMode.orientationModeAdaptive,
          ),
        );
        await _engine!.startPreview();
      } else {
        await _engine!.disableVideo();
        await _engine!.enableLocalVideo(false);
      }
    } catch (e) {
      debugPrint('⚠️ Video config error: $e');
    }

    _isEngineInitialized = true;
    _engineReady = true;
    notifyListeners();

    // 9. Join Channel
    try {
      if (_joined == false) {
        await _engine!.joinChannel(
          token: agoraToken,
          channelId: channelName,
          uid: 0,
          options: ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishCameraTrack: _isVideoMode,
            publishMicrophoneTrack: true,
            autoSubscribeVideo: true,
            autoSubscribeAudio: true,
          ),
        );

        try {
          await _engine!.setEnableSpeakerphone(_speakerOn);
        } catch (e) {
          debugPrint('⚠️ setEnableSpeakerphone error: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ joinChannel() EXCEPTION: $e');
      onCallEnded?.call();
    }
  }

  /// Request token baru dari backend dan perbarui di engine secara dinamis
  Future<void> renewToken(String channelName) async {
    if (_engine == null || !_isEngineInitialized) return;
    try {
      final apiService = CallApiService();
      final newToken = await apiService.fetchAgoraToken(channelName);
      if (newToken.isNotEmpty) {
        await _engine!.renewToken(newToken);
        debugPrint('✅ Agora token renewed successfully');
      }
    } catch (e) {
      debugPrint('⚠️ Gagal renew Agora token: $e');
    }
  }

  void toggleMute() {
    if (_engine == null || !_isEngineInitialized) return;
    _muted = !_muted;
    _engine!.muteLocalAudioStream(_muted);
    notifyListeners();
  }

  void toggleSpeaker() {
    if (_engine == null || !_isEngineInitialized) return;
    _speakerOn = !_speakerOn;
    _engine!.setEnableSpeakerphone(_speakerOn);
    notifyListeners();
  }

  void toggleCamera() {
    if (_engine == null || !_isEngineInitialized) return;
    _cameraOff = !_cameraOff;
    _engine!.muteLocalVideoStream(_cameraOff);
    _engine!.enableLocalVideo(!_cameraOff);
    notifyListeners();
  }

  void switchCamera() {
    if (_engine == null || !_isEngineInitialized) return;
    _engine!.switchCamera();
    _isFrontCamera = !_isFrontCamera;
    notifyListeners();
  }

  Future<void> upgradeToVideo() async {
    if (_engine == null || !_isEngineInitialized) return;
    await _engine!.enableVideo();
    await _engine!.enableLocalVideo(true);
    await _engine!.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 480),
        frameRate: 15,
        bitrate: 0,
        orientationMode: OrientationMode.orientationModeAdaptive,
      ),
    );
    await _engine!.startPreview();
    await _engine!.updateChannelMediaOptions(
      const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
      ),
    );
    _isVideoMode = true;
    _cameraOff = false;
    notifyListeners();
  }



  /// Mengirim permintaan upgrade panggilan suara ke panggilan video secara instan
  Future<void> requestVideoUpgrade(String otherUserId, String channelName) async {
    if (_isWaitingVideoUpgrade) return;
    _isWaitingVideoUpgrade = true;
    notifyListeners();

    // Langsung aktifkan kamera lokal pengirim secara instan!
    await upgradeToVideo();

    try {
      final apiService = CallApiService();
      await apiService.sendCallSignal(
        targetId: otherUserId,
        channelName: channelName,
        signalType: 'request_video',
      );
      debugPrint('📹 [AgoraCallController] Sinyal request_video berhasil dikirim ke $otherUserId.');
    } catch (e) {
      _isWaitingVideoUpgrade = false;
      notifyListeners();
      
      String errorMsg = '⚠️ Gagal mengirim sinyal video: $e';
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          errorMsg = '⚠️ Penerima sedang tidak aktif (FCM tidak terdaftar)';
        } else if (e.response?.data != null && e.response?.data is Map && e.response?.data['error'] != null) {
          errorMsg = '⚠️ ${e.response?.data['error']}';
        } else {
          errorMsg = '⚠️ Koneksi server gagal';
        }
      }
      
      onShowMessage?.call(errorMsg);
    }
  }

  /// Mengirim tanggapan terhadap permintaan panggilan video
  Future<void> sendVideoUpgradeResponse(String otherUserId, String channelName, bool accept) async {
    try {
      final apiService = CallApiService();
      await apiService.sendCallSignal(
        targetId: otherUserId,
        channelName: channelName,
        signalType: accept ? 'accept_video' : 'decline_video',
      );
      debugPrint('📹 [AgoraCallController] Sinyal tanggapan video (${accept ? 'accept' : 'decline'}) dikirim ke $otherUserId.');
      
      if (accept) {
        await upgradeToVideo();
      }
    } catch (e) {
      String errorMsg = '⚠️ Gagal mengirim tanggapan upgrade video: $e';
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          errorMsg = '⚠️ Penerima tidak dapat menerima tanggapan (FCM tidak aktif)';
        } else if (e.response?.data != null && e.response?.data is Map && e.response?.data['error'] != null) {
          errorMsg = '⚠️ ${e.response?.data['error']}';
        } else {
          errorMsg = '⚠️ Koneksi server gagal';
        }
      }
      debugPrint('[AgoraCallController] $errorMsg');
    }
  }

  /// Menangani sinyal upgrade video dari FCM/Pusher secara real-time
  void handleIncomingSignal(Map<String, dynamic> data) async {
    final signalType = data['signal_type']?.toString();
    final callerId = data['caller_id']?.toString() ?? data['sender_id']?.toString() ?? '';
    final channelName = data['channel_name']?.toString() ?? '';

    debugPrint('📹 [AgoraCallController] handleIncomingSignal: $signalType');

    if (signalType == 'request_video') {
      // Langsung aktifkan kamera lokal penerima secara otomatis tanpa konfirmasi!
      await upgradeToVideo();
      // Kirim sinyal konfirmasi balik ke pengirim secara otomatis
      await sendVideoUpgradeResponse(callerId, channelName, true);
    } else if (signalType == 'accept_video') {
      _isWaitingVideoUpgrade = false;
      notifyListeners();
      onShowMessage?.call('📹 Panggilan beralih ke video');
    } else if (signalType == 'decline_video') {
      _isWaitingVideoUpgrade = false;
      notifyListeners();
    }
  }

  /// Rilis asinkronus engine Agora untuk membersihkan resource
  Future<void> disposeEngine() async {
    if (_engine == null) return;

    final engineRef = _engine;
    _engine = null;
    _isEngineInitialized = false;
    _engineReady = false;
    _localUid = null;
    notifyListeners();

    final releaseFuture = Future(() async {
      if (_joined) {
        try {
          await engineRef?.leaveChannel();
        } catch (_) {}
      }
      try {
        await engineRef?.stopPreview();
      } catch (_) {}
      try {
        await engineRef?.release();
      } catch (_) {}
    });

    _activeReleaseFuture = releaseFuture;
    await releaseFuture;
    _joined = false;
  }
}
