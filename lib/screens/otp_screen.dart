import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../utils/colors.dart';
import 'main_nav_screen.dart';

/// OTP Verifikasi untuk Pendaftaran Akun Baru
class OtpScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String email;
  final String password;
  final int expiresIn;

  const OtpScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
    this.expiresIn = 300,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final _auth = AuthService();
  final List<TextEditingController> _ctrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  int _countdown = 0;
  Timer? _timer;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _countdown = widget.expiresIn;
    _startCountdown();

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 12)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeCtrl);

    WidgetsBinding.instance.addPostFrameCallback((_) => _nodes[0].requestFocus());
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 0) { t.cancel(); } else { setState(() => _countdown--); }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    for (final c in _ctrls) c.dispose();
    for (final f in _nodes) f.dispose();
    super.dispose();
  }

  String get _otpCode => _ctrls.map((c) => c.text).join();
  String get _formattedCountdown {
    final m = _countdown ~/ 60, s = _countdown % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyOtp() async {
    final code = _otpCode;
    if (code.length < 6) { _showError('Masukkan 6 digit kode OTP'); return; }

    setState(() => _loading = true);
    final error = await _auth.verifyOtp(widget.email, code);
    setState(() => _loading = false);

    if (error != null) {
      _shakeCtrl.forward(from: 0);
      _showError(error);
      for (final c in _ctrls) c.clear();
      _nodes[0].requestFocus();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) ChatService().setToken(token);
      if (mounted) _showSuccessAndNavigate();
    }
  }

  void _showSuccessAndNavigate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Verifikasi Berhasil!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: RupiaColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Akun Anda telah terverifikasi.\nSelamat datang di RupiaChat!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: RupiaColors.textSecondary)),
          ]),
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavScreen()), (route) => false);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_countdown > 0 || _resending) return;
    setState(() => _resending = true);
    final result = await _auth.resendOtp(widget.name, widget.phone, widget.email, widget.password);
    setState(() => _resending = false);
    if (result['success'] == true) {
      setState(() => _countdown = result['expires_in'] ?? 300);
      _startCountdown();
      _showSuccess('Kode OTP baru telah dikirim');
      for (final c in _ctrls) c.clear();
      _nodes[0].requestFocus();
    } else {
      _showError(result['error'] ?? 'Gagal mengirim ulang OTP');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: RupiaColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: const Color(0xFF4CAF50),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: RupiaColors.primary), useMaterial3: true,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // ── GRADIENT HEADER ─────────────────────────────
            Container(
              height: MediaQuery.of(context).size.height * 0.35,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D2B6B), RupiaColors.primary, Color(0xFF2557B3)],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
            ),

            // ── CONTENT ─────────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // ── Top Bar ──────────────────────────────
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Icon ─────────────────────────────────
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.verified_outlined, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text('Verifikasi OTP',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Kode 6 digit dikirim ke\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75), height: 1.5)),
                    const SizedBox(height: 28),

                    // ── CARD ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        children: [
                          // ── OTP Boxes ──────────────────────
                          AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(
                                _shakeCtrl.isAnimating
                                    ? _shakeAnim.value * ((_shakeCtrl.value * 10).toInt().isEven ? 1 : -1) : 0, 0),
                              child: child,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(6, (i) => _buildOtpBox(i)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Timer Badge ────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: (_countdown > 0 ? RupiaColors.primary : RupiaColors.danger).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(_countdown > 0 ? Icons.timer_outlined : Icons.timer_off_outlined,
                                  size: 16, color: _countdown > 0 ? RupiaColors.primary : RupiaColors.danger),
                              const SizedBox(width: 6),
                              Text(_countdown > 0 ? 'Berlaku $_formattedCountdown' : 'Kode kadaluarsa',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                      color: _countdown > 0 ? RupiaColors.primary : RupiaColors.danger)),
                            ]),
                          ),
                          const SizedBox(height: 20),

                          // ── Verify Button ─────────────────
                          SizedBox(
                            width: double.infinity, height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RupiaColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: _loading ? null : _verifyOtp,
                              child: _loading
                                  ? const SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Verifikasi',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Resend ─────────────────────────
                          TextButton(
                            onPressed: _countdown <= 0 && !_resending ? _resendOtp : null,
                            child: _resending
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(
                                    _countdown > 0 ? 'Kirim ulang dalam $_formattedCountdown' : 'Kirim Ulang Kode OTP',
                                    style: TextStyle(
                                      color: _countdown > 0 ? RupiaColors.textHint : RupiaColors.primary,
                                      fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Info Box ─────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline, color: RupiaColors.primary.withOpacity(0.6), size: 18),
                        const SizedBox(width: 10),
                        const Expanded(child: Text(
                          'Kode OTP dikirim ke Email dan WhatsApp Anda.\nCek folder Spam jika tidak menemukan email.',
                          style: TextStyle(fontSize: 11, color: RupiaColors.textSecondary, height: 1.5),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBox(int i) {
    final hasValue = _ctrls[i].text.isNotEmpty;
    return SizedBox(
      width: 44, height: 52,
      child: TextField(
        controller: _ctrls[i],
        focusNode: _nodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: RupiaColors.primary),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: hasValue ? RupiaColors.primary.withOpacity(0.06) : RupiaColors.bg,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: hasValue ? RupiaColors.primary.withOpacity(0.4) : Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: RupiaColors.primary, width: 2),
          ),
        ),
        onChanged: (v) {
          setState(() {});
          if (v.isNotEmpty && i < 5) _nodes[i + 1].requestFocus();
          if (_otpCode.length == 6) _verifyOtp();
        },
      ),
    );
  }
}
