import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

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
            title: const Text('Notifikasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text('Notifikasi Pesan Baru', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            subtitle: const Text('Tampilkan notifikasi saat ada pesan masuk'),
            value: true,
            activeColor: RupiaColors.primary,
            onChanged: (v) {},
          ),
          const Divider(),
          SwitchListTile(
            title: Text('Notifikasi Transaksi', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            subtitle: const Text('Tampilkan notifikasi untuk pembayaran'),
            value: true,
            activeColor: RupiaColors.primary,
            onChanged: (v) {},
          ),
        ],
      ),
    );
  }
}
