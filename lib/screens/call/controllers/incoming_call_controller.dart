import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/call_api_service.dart';

class IncomingCallController extends ChangeNotifier {
  final String callerId;
  final String channelName;
  final String callType;
  final VoidCallback? onAutoDecline;

  Timer? _autoDeclineTimer;
  bool _isResponded = false;

  bool get isResponded => _isResponded;

  IncomingCallController({
    required this.callerId,
    required this.channelName,
    required this.callType,
    this.onAutoDecline,
  }) {
    _initIncomingCall();
  }

  void _initIncomingCall() {
    // Jalankan haptic feedback getar
    HapticFeedback.heavyImpact();

    // Jalankan timer auto decline 60 detik
    _autoDeclineTimer = Timer(const Duration(seconds: 60), () {
      if (!_isResponded) {
        declineCall().then((_) {
          onAutoDecline?.call();
        });
      }
    });
  }

  /// Membatalkan timer dan menandai panggilan diterima
  void acceptCall() {
    if (_isResponded) return;
    _isResponded = true;
    _autoDeclineTimer?.cancel();
    notifyListeners();
  }

  /// Menolak panggilan secara asinkronus dengan mengirimkan sinyal decline
  Future<void> declineCall() async {
    if (_isResponded) return;
    _isResponded = true;
    _autoDeclineTimer?.cancel();
    notifyListeners();

    await _sendDeclineSignal();
  }

  Future<void> _sendDeclineSignal() async {
    try {
      final apiService = CallApiService();

      // Kirim sinyal decline ke penelpon
      await apiService.sendCallSignal(
        targetId: callerId,
        channelName: channelName,
        signalType: 'decline',
      );

      // Simpan log panggilan sebagai 'declined'
      await apiService.saveCallLog(
        otherUserId: callerId,
        channelName: channelName,
        isVideoMode: callType == 'video',
        remoteUserJoined: false,
        durationSeconds: 0,
        status: 'declined',
      );
    } catch (e) {
      debugPrint('[IncomingCallController] Error sending decline signal: $e');
    }
  }

  @override
  void dispose() {
    _autoDeclineTimer?.cancel();
    super.dispose();
  }
}
