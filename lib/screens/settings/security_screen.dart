import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? RupiaColors.bgDark : RupiaColors.bg,
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
            title: const Text('Keamanan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.password, color: RupiaColors.primary),
            title: Text('Ganti Kata Sandi', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur ganti sandi segera hadir')));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.fingerprint, color: RupiaColors.primary),
            title: Text('Autentikasi Biometrik', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            trailing: Switch(value: false, onChanged: (v){}),
          ),
        ],
      ),
    );
  }
}
