import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/colors.dart';
import 'forgot_password_otp_screen.dart';

/// Lupa Password — Langkah 1: Masukkan Email
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: RupiaColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) { _showError('Email tidak boleh kosong'); return; }

    setState(() => _loading = true);
    final result = await _auth.requestPasswordResetOtp(email);
    setState(() => _loading = false);

    if (result['success'] == true) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ForgotPasswordOtpScreen(
            email: email, expiresIn: result['expires_in'] ?? 300),
        ));
      }
    } else {
      _showError(result['error'] ?? 'Gagal mengirim kode OTP');
    }
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
                      child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text('Lupa Password?',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Masukkan email yang terdaftar\nuntuk menerima kode verifikasi.',
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Alamat Email',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: RupiaColors.textPrimary)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            style: const TextStyle(color: RupiaColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'contoh@email.com',
                              hintStyle: TextStyle(color: RupiaColors.textHint.withOpacity(0.6)),
                              prefixIcon: const Icon(Icons.email_outlined, color: RupiaColors.primary, size: 20),
                              filled: true,
                              fillColor: RupiaColors.bg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: RupiaColors.primary, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity, height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RupiaColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Kirim Kode Verifikasi',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Info Box ─────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Icon(Icons.info_outline, color: RupiaColors.primary.withOpacity(0.6), size: 18),
                        const SizedBox(width: 10),
                        const Expanded(child: Text(
                          'Kode OTP akan dikirim ke Email dan WhatsApp\nyang terdaftar di akun Anda.',
                          style: TextStyle(fontSize: 11, color: RupiaColors.textSecondary, height: 1.5),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: RichText(text: TextSpan(style: const TextStyle(fontSize: 13), children: [
                        TextSpan(text: 'Sudah ingat? ', style: TextStyle(color: RupiaColors.textHint)),
                        const TextSpan(text: 'Kembali login',
                            style: TextStyle(color: RupiaColors.primary, fontWeight: FontWeight.w700)),
                      ])),
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
}
