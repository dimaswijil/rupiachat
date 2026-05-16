import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/colors.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers untuk setiap field input ──
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ── FocusNode untuk navigasi antar field via keyboard ──
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  final _auth = AuthService();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ── Animasi fade-in + slide-up — SAMA dengan Login ──
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Form muncul dari bawah dengan efek fade-in (identik Login)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    // Bersihkan semua resource agar tidak terjadi memory leak
    _animController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  // ── Proses pendaftaran: validasi → request OTP → navigasi ──
  void _register() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validasi: semua field wajib diisi
    if (name.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showError('Mohon lengkapi semua data');
      return;
    }

    // Validasi: password dan konfirmasi harus sama
    if (password != confirmPassword) {
      _showError('Password dan Konfirmasi Password tidak cocok');
      return;
    }

    // Validasi: password minimal 6 karakter
    if (password.length < 6) {
      _showError('Password harus minimal 6 karakter');
      return;
    }

    setState(() => _loading = true);
    final result = await _auth.requestOtp(name, phone, email, password);
    setState(() => _loading = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kode OTP telah dikirim ke email'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              name: name,
              phone: phone,
              email: email,
              password: password,
              expiresIn: result['expires_in'] ?? 300,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        _showError(result['error'] ?? 'Gagal mendaftar');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: RupiaColors.danger,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Helper: build input field — styling IDENTIK dengan Login ──
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    FocusNode? focusNode,
    TextInputAction textInputAction = TextInputAction.next,
    Function(String)? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          // Warna icon abu-abu — SAMA dengan Login (bukan biru)
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: RupiaColors.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Paksa light theme agar konsisten dengan halaman Login
    return Theme(
      data: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: RupiaColors.primary),
      ),
      child: Scaffold(
        // Background biru gelap — menyatu sempurna dengan header
        backgroundColor: const Color(0xFF0D2B6B),
        body: SingleChildScrollView(
          // ClampingScrollPhysics: scroll natural saat keyboard muncul
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // ══════════════════════════════════════════
              // HEADER BIRU — IDENTIK dengan Login
              // Stack dipakai agar tombol back bisa di-overlay
              // tanpa menggeser posisi logo (tetap center)
              // ══════════════════════════════════════════
              Stack(
                children: [
                  // Container header — ukuran SAMA PERSIS dengan Login
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      // top+40 — sama dengan Login
                      top: MediaQuery.of(context).padding.top + 40,
                      // bottom 40 — sama dengan Login
                      bottom: 40,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF081B45), // biru sangat gelap di atas
                          Color(0xFF0D2B6B), // biru gelap
                          Color(0xFF1A3C8F), // primary blue
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo ikon chat — padding 20 & size 52 (SAMA Login)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            color: Colors.white,
                            size: 52, // SAMA dengan Login
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Judul "RupiaChat" — 34px (SAMA dengan Login)
                        const Text(
                          'RupiaChat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Subtitle halaman Register
                        Text(
                          'Buat akun baru Anda',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tombol Back — Positioned overlay di pojok kiri atas
                  // Tidak menggeser layout logo agar tetap center & simetris
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    child: IconButton(
                      icon:
                          const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),

              // ══════════════════════════════════════════
              // FORM PUTIH — Sama dengan Login
              // Fade + Slide animasi identik
              // ══════════════════════════════════════════
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    width: double.infinity,
                    // minHeight: pastikan background putih penuh sampai bawah
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.62,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      // Rounded sudut atas — SAMA dengan Login
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 36,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Judul form
                          const Text(
                            'Daftar Sekarang',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: RupiaColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Lengkapi data di bawah untuk membuat akun',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: RupiaColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // ── Field: Nama Lengkap ──
                          _buildTextField(
                            controller: _nameController,
                            focusNode: _nameFocus,
                            label: 'Nama Lengkap',
                            hint: 'Masukkan nama lengkap',
                            icon: Icons.person_outline,
                            onSubmitted: (_) => _phoneFocus.requestFocus(),
                          ),

                          // ── Field: Nomor WhatsApp ──
                          _buildTextField(
                            controller: _phoneController,
                            focusNode: _phoneFocus,
                            label: 'Nomor WhatsApp',
                            hint: 'Contoh: 081234567890',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            onSubmitted: (_) => _emailFocus.requestFocus(),
                          ),

                          // ── Field: Email ──
                          _buildTextField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            label: 'Email',
                            hint: 'nama@email.com',
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            onSubmitted: (_) => _passwordFocus.requestFocus(),
                          ),

                          // ── Field: Password + tombol show/hide ──
                          _buildTextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            label: 'Password',
                            hint: 'Minimal 6 karakter',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                            onSubmitted: (_) =>
                                _confirmPasswordFocus.requestFocus(),
                          ),

                          // ── Field: Konfirmasi Password + tombol show/hide ──
                          // Perbaikan: ikon diubah dari lock_clock_outlined → lock_outline
                          _buildTextField(
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocus,
                            label: 'Konfirmasi Password',
                            hint: 'Ketik ulang password',
                            icon: Icons.lock_outline,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(() =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword),
                            ),
                            onSubmitted: (_) => _register(),
                          ),

                          const SizedBox(height: 12),

                          // ── Tombol DAFTAR SEKARANG — IDENTIK dengan tombol MASUK di Login ──
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RupiaColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor:
                                    RupiaColors.primary.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _loading ? null : _register,
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'DAFTAR SEKARANG',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Link kembali ke Login — IDENTIK dengan Login ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Sudah punya akun?',
                                style:
                                    TextStyle(color: Colors.grey.shade600),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: RupiaColors.primary,
                                ),
                                child: const Text(
                                  'Masuk Sekarang',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
