import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/colors.dart';

/// Lupa Password — Langkah 3: Buat Password Baru
class ForgotPasswordNewScreen extends StatefulWidget {
  final String email;
  final String otpCode;

  const ForgotPasswordNewScreen({
    super.key, required this.email, required this.otpCode,
  });

  @override
  State<ForgotPasswordNewScreen> createState() => _ForgotPasswordNewScreenState();
}

class _ForgotPasswordNewScreenState extends State<ForgotPasswordNewScreen> {
  final _auth = AuthService();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  double _strength = 0;
  String _strengthLabel = '';
  Color _strengthColor = RupiaColors.textHint;

  @override
  void dispose() { _passCtrl.dispose(); _confirmCtrl.dispose(); super.dispose(); }

  void _evaluateStrength(String p) {
    double s = 0;
    if (p.length >= 6) s += 0.25;
    if (p.length >= 10) s += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(p)) s += 0.2;
    if (RegExp(r'[0-9]').hasMatch(p)) s += 0.2;
    if (RegExp(r'[!@#\$%\^&\*\(\),.?":{}|<>]').hasMatch(p)) s += 0.2;

    String label; Color color;
    if (s <= 0.25)     { label = 'Lemah'; color = RupiaColors.danger; }
    else if (s <= 0.5) { label = 'Cukup'; color = RupiaColors.gold; }
    else if (s <= 0.75){ label = 'Baik';  color = const Color(0xFF66BB6A); }
    else               { label = 'Kuat';  color = RupiaColors.success; }

    setState(() { _strength = s.clamp(0.0, 1.0); _strengthLabel = label; _strengthColor = color; });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: RupiaColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submit() async {
    final pass = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (pass.length < 6) { _showError('Password minimal 6 karakter'); return; }
    if (pass != confirm) { _showError('Konfirmasi password tidak cocok'); return; }

    setState(() => _loading = true);
    final error = await _auth.resetPassword(widget.email, widget.otpCode, pass);
    setState(() => _loading = false);

    if (error != null) { _showError(error); } else { _showSuccessDialog(); }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: Color(0xFF43A047), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Password Berhasil Diubah!', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: RupiaColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Silakan masuk kembali\ndengan password baru Anda.', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: RupiaColors.textSecondary, height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RupiaColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                ),
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Masuk Sekarang',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
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
                      child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text('Buat Password Baru',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Password baru harus berbeda\ndari yang pernah digunakan.',
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Password Baru ──────────────────
                          const Text('Password Baru',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: RupiaColors.textPrimary)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            onChanged: _evaluateStrength,
                            style: const TextStyle(color: RupiaColors.textPrimary, fontSize: 14),
                            decoration: _inputDecor(
                              hint: 'Minimal 6 karakter', icon: Icons.lock_outline,
                              obscure: _obscurePass,
                              onToggle: () => setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),

                          // ── Strength Meter ─────────────────
                          if (_passCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _strength,
                                  backgroundColor: RupiaColors.textHint.withOpacity(0.15),
                                  valueColor: AlwaysStoppedAnimation(_strengthColor),
                                  minHeight: 4,
                                ),
                              )),
                              const SizedBox(width: 10),
                              Text(_strengthLabel,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _strengthColor)),
                            ]),
                            const SizedBox(height: 4),
                            Text('Tips: Gunakan huruf besar, angka, dan simbol',
                                style: TextStyle(fontSize: 10.5, color: RupiaColors.textHint.withOpacity(0.7))),
                          ],
                          const SizedBox(height: 20),

                          // ── Konfirmasi ─────────────────────
                          const Text('Konfirmasi Password',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: RupiaColors.textPrimary)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _confirmCtrl,
                            obscureText: _obscureConfirm,
                            style: const TextStyle(color: RupiaColors.textPrimary, fontSize: 14),
                            decoration: _inputDecor(
                              hint: 'Ulangi password baru', icon: Icons.shield_outlined,
                              obscure: _obscureConfirm,
                              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Submit ─────────────────────────
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
                                  : const Text('Simpan Password Baru',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
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

  InputDecoration _inputDecor({
    required String hint, required IconData icon,
    required bool obscure, required VoidCallback onToggle,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: RupiaColors.textHint.withOpacity(0.6), fontSize: 13),
      prefixIcon: Icon(icon, color: RupiaColors.primary, size: 20),
      suffixIcon: IconButton(
        icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: RupiaColors.textHint, size: 20),
        onPressed: onToggle,
      ),
      filled: true,
      fillColor: RupiaColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: RupiaColors.primary, width: 1.5),
      ),
    );
  }
}
