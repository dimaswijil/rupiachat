import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../utils/colors.dart';
import 'main_nav_screen.dart';
import 'otp_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();

  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      _showError('Email dan password tidak boleh kosong');
      return;
    }
    if (!_isLogin && _nameCtrl.text.trim().isEmpty) {
      _showError('Nama tidak boleh kosong');
      return;
    }
    if (!_isLogin && _phoneCtrl.text.trim().isEmpty) {
      _showError('Nomor telepon tidak boleh kosong');
      return;
    }

    setState(() => _loading = true);

    if (_isLogin) {
      final error = await _auth.login(
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
      );
      setState(() => _loading = false);

      if (error != null) {
        _showError(error);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null) ChatService().setToken(token);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavScreen()),
          );
        }
      }
    } else {
      final result = await _auth.requestOtp(
        _nameCtrl.text.trim(),
        _phoneCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
      );
      setState(() => _loading = false);

      if (result['success'] == true) {
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OtpScreen(
              name: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              password: _passCtrl.text.trim(),
              expiresIn: result['expires_in'] ?? 300,
            ),
          ));
        }
      } else {
        _showError(result['error'] ?? 'Gagal mengirim OTP');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: RupiaColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: RupiaColors.primary),
        useMaterial3: true,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // ── GRADIENT BACKGROUND ─────────────────────────
            Container(
              height: MediaQuery.of(context).size.height * 0.42,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
                    const SizedBox(height: 36),

                    // ── Logo ─────────────────────────────────
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Rp',
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 12),
                    const Text('RupiaChat',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('Chat & Bayar dalam Satu App',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7))),
                    const SizedBox(height: 32),

                    // ── CARD ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ── Tab Toggle ─────────────────────
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: RupiaColors.bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              _TabBtn(label: 'Masuk', isActive: _isLogin,
                                  onTap: () => setState(() => _isLogin = true)),
                              _TabBtn(label: 'Daftar', isActive: !_isLogin,
                                  onTap: () => setState(() => _isLogin = false)),
                            ]),
                          ),
                          const SizedBox(height: 20),

                          // ── Fields ─────────────────────────
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: Column(
                              children: [
                                if (!_isLogin) ...[
                                  _InputField(ctrl: _nameCtrl, label: 'Nama Lengkap', icon: Icons.person_outline),
                                  const SizedBox(height: 12),
                                  _InputField(ctrl: _phoneCtrl, label: 'Nomor Telepon', icon: Icons.phone_outlined,
                                      type: TextInputType.phone),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
                          ),

                          _InputField(ctrl: _emailCtrl, label: 'Email', icon: Icons.email_outlined,
                              type: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _InputField(ctrl: _passCtrl, label: 'Password', icon: Icons.lock_outline, isPassword: true),

                          // ── Lupa Password ─────────────────
                          if (_isLogin)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.only(top: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Lupa Password?',
                                    style: TextStyle(color: RupiaColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                            ),
                          const SizedBox(height: 20),

                          // ── Submit ─────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 50,
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
                                  : Text(_isLogin ? 'Masuk' : 'Daftar Sekarang',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Menghubungkan ke server RupiaChat',
                        style: TextStyle(fontSize: 11, color: RupiaColors.textHint.withOpacity(0.6))),
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

// ── Tab Button ──────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isActive ? RupiaColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                color: isActive ? Colors.white : RupiaColors.textSecondary,
                fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ),
    );
  }
}

// ── Input Field ──────────────────────────────────────────────
class _InputField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType type;
  const _InputField({required this.ctrl, required this.label, required this.icon,
      this.isPassword = false, this.type = TextInputType.text});

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.ctrl,
      obscureText: widget.isPassword && _hide,
      keyboardType: widget.type,
      style: const TextStyle(color: RupiaColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(color: RupiaColors.textSecondary, fontSize: 14),
        prefixIcon: Icon(widget.icon, color: RupiaColors.primary, size: 20),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(_hide ? Icons.visibility_off : Icons.visibility, color: RupiaColors.textHint, size: 20),
                onPressed: () => setState(() => _hide = !_hide),
              )
            : null,
        filled: true,
        fillColor: RupiaColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RupiaColors.primary, width: 1.5),
        ),
      ),
    );
  }
}