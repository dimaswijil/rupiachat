import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/call_api_service.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../models/group_model.dart';
import 'controllers/agora_group_call_controller.dart';
import 'widgets/group/group_call_background.dart';
import 'widgets/group/group_call_top_bar.dart';
import 'widgets/group/group_call_voice_ui.dart';
import 'widgets/group/group_call_video_grid.dart';
import 'widgets/group/group_call_controls.dart';

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
  late final AgoraGroupCallController _controller;
  final CallApiService _apiService = CallApiService();
  GroupModel? _groupDetail;

  int _seconds = 0;
  Timer? _timer;
  bool _isEnding = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Inisialisasi pengontrol panggilan grup Agora
    _controller = AgoraGroupCallController(
      isVideoCall: widget.isVideoCall,
      onLocalJoined: () {
        _startTimer();
      },
      onCallEnded: () {
        if (mounted && !_isEnding) _endCall();
      },
    );

    _controller.addListener(_onControllerChanged);
    _initAgora();
    _loadGroupDetail();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadGroupDetail() async {
    try {
      final detail = await GroupService().getGroupDetail(widget.channelName);
      if (mounted && detail != null) {
        setState(() {
          _groupDetail = detail;
        });
      }
    } catch (e) {
      debugPrint('Error fetching group detail: $e');
    }
  }

  Future<void> _initAgora() async {
    final currentUid = await AuthService().currentUid;
    if (currentUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Sesi login tidak ditemukan'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
      return;
    }
    await _controller.initAgora(
      channelName: widget.channelName,
      currentUid: currentUid,
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _stopTimer() => _timer?.cancel();

  void _endCall() async {
    if (_isEnding) return;
    _isEnding = true;
    _stopTimer();
    try {
      _pulseController.stop();
    } catch (_) {}

    final channelId = 'group_${widget.channelName}';
    // Simpan log panggilan grup ke database via CallApiService
    await _apiService.saveGroupCallLog(
      groupId: widget.channelName,
      groupName: widget.groupName,
      channelId: channelId,
      isVideoMode: _controller.isVideoMode,
      hasParticipants: _controller.remoteUsers.isNotEmpty,
      durationSeconds: _seconds,
    );

    await _controller.disposeEngine();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _stopTimer();
    _pulseController.dispose();
    _controller.disposeEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mapping remote user IDs to real group member names
    final Map<String, String> memberNames = {};
    if (_groupDetail != null) {
      for (var member in _groupDetail!.members) {
        memberNames[member.id] = member.name;
      }
    }

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
            const GroupCallBackground(),
            // Content
            SafeArea(
              child: Column(
                children: [
                  GroupCallTopBar(
                    groupName: widget.groupName,
                    localJoined: _controller.localJoined,
                    participantCount: _controller.remoteUsers.length + 1,
                    isVideoMode: _controller.isVideoMode,
                    seconds: _seconds,
                    onEndCall: _endCall,
                    onUpgradeToVideo: _controller.upgradeToVideo,
                    onSwitchCamera: _controller.switchCamera,
                  ),
                  Expanded(
                    child: _controller.isVideoMode && _controller.remoteUsers.isNotEmpty
                        ? GroupCallVideoGrid(
                            engine: _controller.engine!,
                            channelName: widget.channelName,
                            remoteUsers: _controller.remoteUsers,
                            cameraOff: _controller.cameraOff,
                            muted: _controller.muted,
                            engineReady: _controller.engineReady,
                            localUid: _controller.localUid,
                            isFrontCamera: _controller.isFrontCamera,
                            memberNames: memberNames,
                          )
                        : GroupCallVoiceUI(
                            remoteUserIds: _controller.remoteUsers.keys.toList(),
                            pulseAnimation: _pulseAnimation,
                          ),
                  ),
                  GroupCallControls(
                    isVideoMode: _controller.isVideoMode,
                    muted: _controller.muted,
                    cameraOff: _controller.cameraOff,
                    speakerOn: _controller.speakerOn,
                    onMute: _controller.toggleMute,
                    onCamera: _controller.toggleCamera,
                    onSpeaker: _controller.toggleSpeaker,
                    onEndCall: _endCall,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
