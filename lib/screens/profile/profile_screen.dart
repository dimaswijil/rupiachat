import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // <--- Pastikan ini ada
import 'package:image_cropper/image_cropper.dart'; // Import buat fitur tata letak
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/purchase_service.dart'; // Tambahkan ini
import '../purchase/purchase_screen.dart'; // Tambahkan ini
import '../../utils/colors.dart';
import '../../main.dart'; 
import 'edit_profile_screen.dart';
import '../settings/security_screen.dart';
import '../settings/notification_screen.dart';
import '../settings/help_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final ImagePicker _picker = ImagePicker(); // Gunakan tipe ImagePicker secara eksplisit

  String _name     = '';
  String _email    = '';
  String _phone    = '';
  String _photoUrl = '';
  String _initials = '';
  bool _loading    = true;
  bool _isDark     = false;
  bool _isThemeProUnlocked = false;

  final List<Map<String, dynamic>> _themeColors = [
    {'name': 'Royal Blue', 'color': const Color(0xFF1A3C8F), 'isDefault': true},
    {'name': 'Emerald Green', 'color': const Color(0xFF0F6E56), 'isDefault': false},
    {'name': 'Deep Teal', 'color': const Color(0xFF008080), 'isDefault': false},
    {'name': 'Indigo Purple', 'color': const Color(0xFF4B0082), 'isDefault': false},
    {'name': 'Sunset Amber', 'color': const Color(0xFFD97706), 'isDefault': false},
    {'name': 'Crimson Red', 'color': const Color(0xFF993C1D), 'isDefault': false},
    {'name': 'Hot Pink', 'color': const Color(0xFFE91E63), 'isDefault': false},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadThemeStatus();
    _checkThemeProStatus();
  }

  Future<void> _checkThemeProStatus() async {
    try {
      final active = await PurchaseService().getActiveFeatures();
      if (mounted) {
        setState(() {
          _isThemeProUnlocked = active.contains('theme_pro') || active.contains('vip_member');
        });
      }
    } catch (e) {
      debugPrint('Error loading theme pro status: $e');
    }
  }

  Future<void> _selectThemeColor(Color color) async {
    await RupiaColors.saveThemeColor(color);
    themeColorNotifier.value = color;
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tema warna berhasil diubah!'),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showThemeProLockedDialog(String colorName, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: RupiaColors.gold),
            SizedBox(width: 8),
            Text('Tema Pro Terkunci 👑', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Dapatkan akses penuh ke kustomisasi warna tema premium (seperti $colorName) dengan mengaktifkan Tema Pro!\n\nApakah Anda ingin membuka sekarang?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RupiaColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PurchaseScreen()),
              ).then((_) => _checkThemeProStatus());
            },
            child: const Text('Buka Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadThemeStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDark = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDark = value;
    });
    await prefs.setBool('isDarkMode', value);
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _loadProfile() async {
    final name  = await _auth.currentName  ?? 'User';
    final email = await _auth.currentEmail ?? '';
    final phone = await _auth.currentPhone ?? '';
    final photo = await _auth.currentPhoto ?? '';

    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    setState(() {
      _name     = name;
      _email    = email;
      _phone    = phone;
      _photoUrl = photo;
      _initials = initials;
      _loading  = false;
    });
  }

  Future<void> _logout() async {
    setState(() => _loading = true);
    await _auth.logout();
    mainNavIndexNotifier.value = 0;
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (image != null) {
        // Fitur tata letak (Crop, Rotate, Scale)
        final CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Paksa jadi kotak untuk profil
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Tata Letak Foto',
              toolbarColor: RupiaColors.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              hideBottomControls: false,
            ),
            IOSUiSettings(
              title: 'Tata Letak Foto',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() => _loading = true);
          
          final error = await _auth.updateProfilePhoto(croppedFile.path);
          
          if (error == null) {
            await _loadProfile();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Foto profil berhasil diperbarui')),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error), backgroundColor: RupiaColors.danger),
              );
            }
          }
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      debugPrint('Error picking or cropping image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: RupiaColors.primary)),
      );
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AnimatedTheme(
      data: Theme.of(context),
      duration: const Duration(milliseconds: 300),
      child: Scaffold(
        backgroundColor: isDarkMode ? RupiaColors.bgDark : RupiaColors.bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF0D2B6B), RupiaColors.primary],
              ),
            ),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Profil',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
            ),
          ),
        ),
        body: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [RupiaColors.primary, RupiaColors.primary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
              child: Center(
                child: Column(children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _photoUrl.isNotEmpty ? () {
                          Navigator.push(context, PageRouteBuilder(
                            opaque: false,
                            transitionDuration: const Duration(milliseconds: 300),
                            pageBuilder: (context, animation, secondaryAnimation) {
                              return FadeTransition(
                                opacity: animation,
                                child: Scaffold(
                                  backgroundColor: Colors.black.withOpacity(0.9),
                                  appBar: AppBar(
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    iconTheme: const IconThemeData(color: Colors.white),
                                  ),
                                  body: Center(
                                    child: InteractiveViewer(
                                      child: Hero(
                                        tag: 'profile_photo',
                                        child: Image.network(_photoUrl),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ));
                        } : null,
                        child: Hero(
                          tag: 'profile_photo',
                          child: Container(
                            width: 100, height: 100,
                            decoration: const BoxDecoration(color: RupiaColors.gold, shape: BoxShape.circle),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: _photoUrl.isNotEmpty
                                  ? Image.network(
                                      _photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => 
                                        Center(child: Text(_initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700))),
                                    )
                                  : Center(child: Text(_initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700))),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[800] : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: Icon(Icons.camera_alt, color: RupiaColors.primary, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            currentName: _name,
                            currentEmail: _email,
                            currentPhone: _phone,
                          ),
                        ),
                      );
                      if (updated == true) {
                        _loadProfile();
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_name,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_phone.isNotEmpty ? '$_email  •  $_phone' : _email, 
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: isDarkMode ? RupiaColors.bgDark : RupiaColors.bg,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                    child: Column(children: [
                      _MenuItem(
                        icon: Icons.person_outline, 
                        label: 'Akun',
                        onTap: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(
                                currentName: _name,
                                currentEmail: _email,
                                currentPhone: _phone,
                              ),
                            ),
                          );
                          if (updated == true) {
                            _loadProfile();
                          }
                        },
                      ),
                      _MenuTile(
                        icon: Icons.palette_outlined,
                        label: 'Penampilan',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_isDark ? 'Mode Gelap' : 'Mode Terang', 
                              style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : RupiaColors.textSecondary)),
                            const SizedBox(width: 8),
                            Switch(
                              value: _isDark,
                              activeColor: RupiaColors.primary,
                              onChanged: _toggleTheme,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── KUSTOMISASI WARNA TEMA PRO ──
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDarkMode ? [] : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.color_lens_outlined, color: RupiaColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Warna Tema (Tema Pro)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                                if (!_isThemeProUnlocked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: RupiaColors.gold.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: RupiaColors.gold.withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.workspace_premium_rounded, color: RupiaColors.gold, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'PRO',
                                          style: TextStyle(
                                            color: RupiaColors.gold,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 52,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _themeColors.length,
                                itemBuilder: (ctx, i) {
                                  final item = _themeColors[i];
                                  final Color color = item['color'] as Color;
                                  final String name = item['name'] as String;
                                  final bool isDefault = item['isDefault'] as bool;
                                  final bool isSelected = themeColorNotifier.value.value == color.value;

                                  // Locked if not default color AND theme pro not unlocked
                                  final bool isLocked = !isDefault && !_isThemeProUnlocked;

                                  return GestureDetector(
                                    onTap: () {
                                      if (isLocked) {
                                        _showThemeProLockedDialog(name, color);
                                      } else {
                                        _selectThemeColor(color);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 14),
                                      child: Tooltip(
                                        message: name,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 250),
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle,
                                                border: isSelected
                                                    ? Border.all(
                                                        color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                                                        width: 3,
                                                      )
                                                    : Border.all(
                                                        color: Colors.transparent,
                                                        width: 0,
                                                      ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: color.withOpacity(0.3),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            if (isLocked)
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.black87,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.lock_rounded,
                                                    color: Colors.amber,
                                                    size: 10,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _MenuItem(
                        icon: Icons.security, 
                        label: 'Keamanan',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen())),
                      ),
                      _MenuItem(
                        icon: Icons.notifications_outlined, 
                        label: 'Notifikasi',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                      ),
                      _MenuItem(
                        icon: Icons.help_outline, 
                        label: 'Bantuan',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
                      ),
                      _MenuItem(
                        icon: Icons.logout, 
                        label: 'Keluar', 
                        isRed: true, 
                        onTap: _logout
                      ),
                    ]),
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;

  const _MenuTile({required this.icon, required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: RupiaColors.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: trailing,
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isRed;
  final VoidCallback? onTap;

  const _MenuItem({required this.icon, required this.label, this.isRed = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isRed ? RupiaColors.danger : RupiaColors.primary),
        title: Text(label,
            style: TextStyle(fontWeight: FontWeight.w500,
                color: isRed ? RupiaColors.danger : (isDarkMode ? Colors.white : RupiaColors.textPrimary))),
        trailing: const Icon(Icons.chevron_right, color: RupiaColors.textHint),
        onTap: onTap ?? () {},
      ),
    );
  }
}
