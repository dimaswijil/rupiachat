import 'dart:async';
import 'package:flutter/material.dart';
import 'call_screen.dart';
import 'group_call_screen.dart';
import 'controllers/incoming_call_controller.dart';
import 'widgets/incoming/incoming_call_background.dart';
import 'widgets/incoming/slide_to_answer.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerId;
  final String channelName;
  final String callType; // 'voice' or 'video'
  final String? callerPhoto;
  final bool isGroupCall;
  final String? groupId;
  final String? groupName;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerId,
    required this.channelName,
    required this.callType,
    this.callerPhoto,
    this.isGroupCall = false,
    this.groupId,
    this.groupName,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late final IncomingCallController _controller;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Slide up animation untuk panel tombol aksi
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    _slideController.forward();

    // Inisialisasi pengontrol panggilan masuk Agora
    _controller = IncomingCallController(
      callerId: widget.callerId,
      channelName: widget.channelName,
      callType: widget.callType,
      onAutoDecline: () {
        if (mounted) Navigator.pop(context);
      },
    );
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _acceptCall() async {
    _controller.acceptCall();

    // Delay minimal agar animasi IncomingCallScreen selesai & dispose bersih
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    if (widget.isGroupCall) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => GroupCallScreen(
            channelName: widget.channelName,
            groupName: widget.groupName ?? widget.callerName,
            isVideoCall: widget.callType == 'video',
          ),
        ),
        (route) => route.isFirst,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            channelName: widget.channelName,
            otherUserName: widget.callerName,
            otherUserId: widget.callerId,
            otherUserPhoto: widget.callerPhoto,
            isVideoCall: widget.callType == 'video',
            isIncoming: true,
          ),
        ),
        (route) => route.isFirst,
      );
    }
  }

  void _declineCall() async {
    // FIXED Bug #19: await decline signal SEBELUM pop
    await _controller.declineCall();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _slideController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';
    final displayName = widget.isGroupCall
        ? (widget.groupName ?? widget.callerName)
        : widget.callerName;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Stack(
        children: [
          // Background gradient + particles
          const IncomingCallBackground(),
          // Main content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                
                // Logo & Call Type Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isVideo ? Icons.videocam_rounded : Icons.phone_callback_rounded,
                      color: const Color(0xFF22C55E),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVideo ? 'RupiaChat Video...' : 'RupiaChat Audio...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Caller name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                
                if (widget.isGroupCall) ...[
                  const SizedBox(height: 8),
                  Text(
                    'dari ${widget.callerName}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                
                const Spacer(flex: 6),

                // Tombol Aksi Cepat: Pesan (Kiri) & Tolak (Kanan)
                SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Tombol Pesan
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Fitur pesan cepat akan segera hadir'),
                                    backgroundColor: Color(0xFF1E212A),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.08),
                                ),
                                child: const Icon(
                                  Icons.message_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Message',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),

                        // Tombol Tolak
                        Column(
                          children: [
                            GestureDetector(
                              onTap: _declineCall,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red.withOpacity(0.15),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.call_end_rounded,
                                  color: Colors.redAccent,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tolak',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Widget Slide to Answer
                SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 28,
                      left: 36,
                      right: 36,
                    ),
                    child: SlideToAnswer(
                      onAnswer: _acceptCall,
                      text: 'slide to answer',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
