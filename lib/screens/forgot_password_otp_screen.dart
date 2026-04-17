import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/colors.dart';
import 'forgot_password_new_screen.dart';

/// Lupa Password — Langkah 2: Verifikasi Kode OTP
class ForgotPasswordOtpScreen extends StatefulWidget {
  final String email;
  final int expiresIn;

  const ForgotPasswordOtpScreen({
    super.key, required this.email, this.expiresIn = 300,
  });

  @override
  State<ForgotPasswordOtpScreen> createState() => _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  final List<TextEditingController> _ctrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

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
    _shakeAnim = Tween<double>(begin: 0, end: 14)
        .chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeCtrl);
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
    _timer?.cancel(); _shakeCtrl.dispose();
    for (final c in _ctrls) c.dispose();
    for (final f in _nodes) f.dispose();
    super.dispose();
  }

  String get _otpCode => _ctrls.map((c) => c.text).join();
  String get _formattedCountdown {
    final m = _countdown ~/ 60, s = _countdown % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
      content: Text(msg), backgroundColor: RupiaColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _resendOtp() async {
    if (_countdown > 0 || _resending) return;
    setState(() => _resending = true);
    final result = await _auth.requestPasswordResetOtp(widget.email);
    setState(() => _resending = false);
    if (result['success'] == true) {
      setState(() => _countdown = result['expires_in'] ?? 300);
      _startCountdown();
      _showSuccess('Kode OTP baru telah dikirim');
      for (final c in _ctrls) c.clear();
      _nodes[0].requestFocus();
    } else {
      _showError(result['error'] ?? 'Gagal mengirim ulang');
    }
  }

  void _verifyAndContinue() {
    final code = _otpCode;
    if (code.length < 6) { _shakeCtrl.forward(from: 0); _showError('Masukkan 6 digit kode OTP'); return; }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ForgotPasswordNewScreen(email: widget.email, otpCode: code),
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

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15), shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text('Verifikasi Kode',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Masukkan kode 6 digit yang\ndikirim ke ${widget.email}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75), height: 1.5)),
                    const SizedBox(height: 28),

                    // ── CARD ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(20),
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

                          // ── Continue ───────────────────────
                          SizedBox(
                            width: double.infinity, height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RupiaColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: _verifyAndContinue,
                              child: const Text('Lanjutkan',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                          ),
                          const SizedBox(height: 12),

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

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
        controller: _ctrls[i], focusNode: _nodes[i],
        keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: RupiaColors.primary),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '', filled: true,
          fillColor: hasValue ? RupiaColors.primary.withOpacity(0.06) : RupiaColors.bg,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: hasValue ? RupiaColors.primary.withOpacity(0.4) : Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: RupiaColors.primary, width: 2)),
        ),
        onChanged: (v) {
          setState(() {});
          if (v.isNotEmpty && i < 5) _nodes[i + 1].requestFocus();
        },
      ),
    );
  }
}
