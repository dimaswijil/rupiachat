import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/call_api_service.dart';

const String _agoraAppId = 'c10911c3802e494dbb69ac8fefb94d57';

class AgoraGroupCallController extends ChangeNotifier {
  RtcEngine? _engine;
  bool _engineReady = false;
  bool _isEngineInitialized = false;
  bool _localJoined = false;
  bool _isVideoMode = false;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn;
  int? _localUid;
  bool _isFrontCamera = true;
  final Map<int, bool> _remoteUsers = {}; // uid -> hasVideo

  // Callbacks untuk komunikasi dengan UI
  VoidCallback? onLocalJoined;
  VoidCallback? onCallEnded;

  // Getters
  RtcEngine? get engine => _engine;
  bool get engineReady => _engineReady;
  bool get localJoined => _localJoined;
  bool get isVideoMode => _isVideoMode;
  bool get muted => _muted;
  bool get cameraOff => _cameraOff;
  bool get speakerOn => _speakerOn;
  int? get localUid => _localUid;
  bool get isFrontCamera => _isFrontCamera;
  Map<int, bool> get remoteUsers => _remoteUsers;

  AgoraGroupCallController({
    required bool isVideoCall,
    this.onLocalJoined,
    this.onCallEnded,
  })  : _isVideoMode = isVideoCall,
        _speakerOn = isVideoCall;

  /// Inisialisasi izin, ambil token grup, inisialisasi RtcEngine, dan join channel grup
  Future<void> initAgora({
    required String channelName,
    required String currentUid,
  }) async {
    // 1. Request permissions
    await [Permission.microphone, Permission.camera].request();

    if (_agoraAppId.isEmpty) {
      debugPrint('⚠️ Agora APP ID belum diisi');
      onCallEnded?.call();
      return;
    }

    final channelId = 'group_$channelName';
    final agoraUid = int.tryParse(currentUid) ?? 0;
    _localUid = agoraUid;
    String agoraToken = '';
    final apiService = CallApiService();

    // 2. Request Agora Token khusus grup dari server
    try {
      agoraToken = await apiService.fetchGroupAgoraToken(
        channelId: channelId,
        currentUid: currentUid,
      );
      if (agoraToken.isEmpty) {
        debugPrint('❌ Token grup kosong dari server');
        onCallEnded?.call();
        return;
      }
      debugPrint('✅ Agora group token diterima: ${agoraToken.substring(0, agoraToken.length.clamp(0, 20))}...');
    } catch (e) {
      debugPrint('❌ Gagal request Agora group token: $e');
      onCallEnded?.call();
      return;
    }

    // 3. Inisialisasi Agora Engine
    try {
      if (_isEngineInitialized) return;

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: _agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    } catch (e) {
      debugPrint('❌ Gagal inisialisasi Agora Group Engine: $e');
      onCallEnded?.call();
      return;
    }

    // 4. Daftarkan event handler
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        _localJoined = true;
        onLocalJoined?.call();
        notifyListeners();
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint('✅ Group remote user joined: $remoteUid');
        _remoteUsers[remoteUid] = false;
        notifyListeners();
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        _remoteUsers.remove(remoteUid);
        notifyListeners();
      },
      onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid,
          RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
        debugPrint('📹 Group remote video uid=$remoteUid state=$state');
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
        notifyListeners();
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint('Agora Group Error: $err - $msg');
        if (err == ErrorCodeType.errInvalidToken || err == ErrorCodeType.errTokenExpired) {
          onCallEnded?.call();
        }
      },
      onConnectionStateChanged: (RtcConnection c, ConnectionStateType s, ConnectionChangedReasonType r) {
        debugPrint('🔄 Group Agora State: $s, Reason: $r');
        if (s == ConnectionStateType.connectionStateFailed) {
          onCallEnded?.call();
        }
      },
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
        debugPrint('⚠️ Group token akan expire — mencoba renew...');
        renewGroupToken(channelName: channelName, currentUid: currentUid);
      },
    ));

    // 5. Konfigurasi audio
    try {
      await _engine!.enableAudio();
    } catch (e) {
      debugPrint('⚠️ Group enableAudio error: $e');
    }

    try {
      await _engine!.setDefaultAudioRouteToSpeakerphone(_speakerOn);
    } catch (e) {
      debugPrint('⚠️ Group setDefaultAudioRouteToSpeakerphone error: $e');
    }

    // 6. Konfigurasi video
    try {
      if (_isVideoMode) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      } else {
        await _engine!.disableVideo();
      }
    } catch (e) {
      debugPrint('⚠️ Group video config error: $e');
    }

    _isEngineInitialized = true;
    _engineReady = true;
    notifyListeners();

    // 7. Join Channel
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

      try {
        await _engine!.setEnableSpeakerphone(_speakerOn);
      } catch (e) {
        debugPrint('⚠️ Group setEnableSpeakerphone error: $e');
      }
    } catch (e) {
      debugPrint('❌ Group joinChannel() EXCEPTION: $e');
      onCallEnded?.call();
    }
  }

  /// Request token baru dari backend dan renew secara dinamis
  Future<void> renewGroupToken({
    required String channelName,
    required String currentUid,
  }) async {
    if (_engine == null || !_isEngineInitialized) return;
    try {
      final channelId = 'group_$channelName';
      final apiService = CallApiService();
      final newToken = await apiService.fetchGroupAgoraToken(
        channelId: channelId,
        currentUid: currentUid,
      );
      if (newToken.isNotEmpty) {
        await _engine!.renewToken(newToken);
        debugPrint('✅ Group Agora token renewed successfully');
      }
    } catch (e) {
      debugPrint('⚠️ Gagal renew group Agora token: $e');
    }
  }

  void toggleMute() {
    if (_engine == null || !_engineReady) return;
    _muted = !_muted;
    _engine!.muteLocalAudioStream(_muted);
    notifyListeners();
  }

  void toggleSpeaker() {
    if (_engine == null || !_engineReady) return;
    _speakerOn = !_speakerOn;
    _engine!.setEnableSpeakerphone(_speakerOn);
    notifyListeners();
  }

  void toggleCamera() {
    if (_engine == null || !_engineReady) return;
    _cameraOff = !_cameraOff;
    _engine!.muteLocalVideoStream(_cameraOff);
    notifyListeners();
  }

  void switchCamera() {
    if (_engine != null && _engineReady) {
      _engine!.switchCamera();
      _isFrontCamera = !_isFrontCamera;
      notifyListeners();
    }
  }

  Future<void> upgradeToVideo() async {
    if (_engine == null || !_engineReady) return;
    await _engine!.enableVideo();
    await _engine!.startPreview();
    await _engine!.updateChannelMediaOptions(const ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      publishCameraTrack: true,
      publishMicrophoneTrack: true,
      autoSubscribeVideo: true,
      autoSubscribeAudio: true,
    ));
    _isVideoMode = true;
    _cameraOff = false;
    notifyListeners();
  }

  /// Rilis asinkronus engine Agora untuk membersihkan resource
  Future<void> disposeEngine() async {
    if (_engine == null) return;
    final engineRef = _engine;
    _engine = null;
    _engineReady = false;
    _isEngineInitialized = false;
    notifyListeners();

    try {
      await engineRef?.leaveChannel();
    } catch (_) {}
    try {
      await engineRef?.stopPreview();
    } catch (_) {}
    try {
      await engineRef?.release();
    } catch (_) {}
  }
}
