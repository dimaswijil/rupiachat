import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
            title: const Text('Bantuan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            leading: const Icon(Icons.help_center, color: RupiaColors.primary),
            title: Text('Pusat Bantuan (FAQ)', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.support_agent, color: RupiaColors.primary),
            title: Text('Hubungi Customer Service', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info, color: RupiaColors.primary),
            title: Text('Tentang RupiaChat', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            subtitle: const Text('Versi 1.0.0'),
          ),
        ],
      ),
    );
  }
}
