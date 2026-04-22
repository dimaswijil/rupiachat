import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // <--- Pastikan ini ada
import 'package:image_cropper/image_cropper.dart'; // Import buat fitur tata letak
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../utils/colors.dart';
import '../main.dart'; 
import 'edit_profile_screen.dart';
import 'settings/security_screen.dart';
import 'settings/notification_screen.dart';
import 'settings/help_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadThemeStatus();
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
      return const Scaffold(
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
            decoration: const BoxDecoration(
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
        body: SingleChildScrollView(
          child: Column(children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [RupiaColors.primary, Color(0xFF2557B3)],
                ),
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
                            child: const Icon(Icons.camera_alt, color: RupiaColors.primary, size: 20),
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
            Container(
              padding: const EdgeInsets.all(20),
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
          ]),
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
