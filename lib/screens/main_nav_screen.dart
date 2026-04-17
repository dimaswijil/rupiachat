import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../main.dart'; // Import mainNavIndexNotifier
import 'chat_list_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';

// MainNavScreen = layar utama dengan bottom navigation bar
class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  // Daftar halaman sesuai urutan tab
  final List<Widget> _screens = const [
    ChatListScreen(),   // index 0 → tab Chat
    WalletScreen(),     // index 1 → tab Wallet
    ProfileScreen(),    // index 2 → tab Profile
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<int>(
      valueListenable: mainNavIndexNotifier,
      builder: (context, currentIndex, child) {
        return Scaffold(
          // Tampilkan halaman sesuai tab yang dipilih
          body: _screens[currentIndex],

          bottomNavigationBar: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,   // Menghilangkan efek gelombang saat diklik
              highlightColor: Colors.transparent, // Menghilangkan efek highlight saat ditekan
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isDarkMode ? RupiaColors.cardDark : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode ? Colors.black26 : const Color(0x14000000),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: (i) => mainNavIndexNotifier.value = i,
                backgroundColor: Colors.transparent,
                selectedItemColor: RupiaColors.primary,
                unselectedItemColor: isDarkMode ? Colors.white38 : RupiaColors.textHint,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.chat_bubble_outline),
                    activeIcon: Icon(Icons.chat_bubble),
                    label: 'Chat',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    activeIcon: Icon(Icons.account_balance_wallet),
                    label: 'Wallet',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
