import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'call_screen.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerId;
  final String channelName;
  final String callType; // 'voice' or 'video'
  final String? callerPhoto;
  // Untuk group call
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
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _autoDeclineTimer;
  bool _isResponded = false;

  @override
  void initState() {
    super.initState();

    // Vibrate
    HapticFeedback.heavyImpact();

    // Pulse animation for avatar
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slide up animation for buttons
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

    // Auto decline after 60 seconds
    _autoDeclineTimer = Timer(const Duration(seconds: 60), () {
      if (!_isResponded && mounted) {
        _declineCall();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _autoDeclineTimer?.cancel();
    super.dispose();
  }

  void _acceptCall() {
    if (_isResponded) return;
    _isResponded = true;
    _autoDeclineTimer?.cancel();

    Navigator.pushReplacement(
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
    );
  }

  void _declineCall() {
    if (_isResponded) return;
    _isResponded = true;
    _autoDeclineTimer?.cancel();

    _sendDeclineSignal();

    Navigator.pop(context);
  }

  Future<void> _sendDeclineSignal() async {
    try {
      final token = await AuthService().currentToken;
      if (token == null) return;
      
      final chatService = ChatService();
      chatService.setToken(token);

      // Kirim sinyal ke penelpon bahwa panggilan ditolak
      await chatService.sendCallSignal(
        receiverId: widget.callerId,
        channelName: widget.channelName,
        signalType: 'decline',
      );

      // Simpan log panggilan sebagai 'declined'
      await chatService.saveCallLog(
        receiverId: widget.callerId,
        channelName: widget.channelName,
        type: widget.callType,
        status: 'declined',
        duration: 0,
      );
    } catch (e) {
      debugPrint('[IncomingCall] Error sending decline signal: $e');
    }
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
          _buildBackground(),
          // Main content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Call type label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        color: const Color(0xFF4ADE80),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isVideo ? 'Panggilan Video Masuk' : 'Panggilan Suara Masuk',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Animated avatar
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    );
                  },
                  child: _buildAvatar(displayName),
                ),
                const SizedBox(height: 28),
                // Caller name
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                if (widget.isGroupCall) ...[
                  const SizedBox(height: 6),
                  Text(
                    'dari ${widget.callerName}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 15,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Animated "Memanggil..." text
                _buildRingingText(),
                const Spacer(flex: 3),
                // Accept / Decline buttons
                SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 40,
                      left: 40,
                      right: 40,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Decline
                        _buildActionButton(
                          icon: Icons.call_end_rounded,
                          label: 'Tolak',
                          gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
                          onTap: _declineCall,
                        ),
                        // Accept
                        _buildActionButton(
                          icon: isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          label: 'Terima',
                          gradient: const [Color(0xFF22C55E), Color(0xFF16A34A)],
                          onTap: _acceptCall,
                        ),
                      ],
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

  Widget _buildAvatar(String name) {
    final initials = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow rings
        ...List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, __) {
              final scale = 1.0 + (i + 1) * 0.15 * _pulseAnimation.value;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2557B3)
                          .withOpacity(0.15 - (i * 0.04)),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          );
        }),
        // Main avatar
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2557B3), Color(0xFF0D2060)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2557B3).withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: widget.callerPhoto != null && widget.callerPhoto!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    widget.callerPhoto!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ),
                )
              : Center(
                  child: Text(initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                      )),
                ),
        ),
      ],
    );
  }

  Widget _buildRingingText() {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: 300),
      duration: const Duration(seconds: 300),
      builder: (_, val, __) {
        final dots = '.' * ((val % 3) + 1);
        return Text(
          'Berdering$dots',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: gradient),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0E21),
            Color(0xFF1A1A3E),
            Color(0xFF0D2B6B),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: const CustomPaint(
        painter: _IncomingParticlePainter(),
        size: Size.infinite,
      ),
    );
  }
}

// ── Subtle background particles ──
class _IncomingParticlePainter extends CustomPainter {
  const _IncomingParticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03);
    final rng = Random(77);
    for (int i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 3 + 1;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
