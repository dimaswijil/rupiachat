import 'package:flutter/material.dart';
import 'dart:ui';
import '../main.dart'; // Import mainNavIndexNotifier
import 'chat/chat_list_screen.dart';
import 'group/group_list_screen.dart';
import 'purchase/purchase_screen.dart';
import 'call/call_history_screen.dart';
import 'profile/profile_screen.dart';
import '../services/purchase_service.dart';

// MainNavScreen = layar utama dengan bottom navigation bar
// Navbar menggunakan efek "Liquid Glass" — transparan, blur, dengan animasi smooth
class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen>
    with TickerProviderStateMixin {
  // Daftar halaman sesuai urutan tab
  final List<Widget> _screens = const [
    ChatListScreen(),       // index 0 → Chat
    GroupListScreen(),      // index 1 → Grup
    PurchaseScreen(),       // index 2 → Beli
    CallHistoryScreen(),    // index 3 → Panggilan
    ProfileScreen(),        // index 4 → Profil
  ];

  // Animasi untuk indikator liquid glass yang bergerak mengikuti tab aktif
  late AnimationController _indicatorController;
  late Animation<double> _indicatorAnimation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    PurchaseService().getActiveFeatures(); // Pre-fetch active features
    _previousIndex = mainNavIndexNotifier.value;

    // Controller untuk animasi perpindahan indikator
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _indicatorAnimation = Tween<double>(
      begin: _previousIndex.toDouble(),
      end: _previousIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _indicatorController,
      curve: Curves.easeOutCubic,
    ));

    // Dengarkan perubahan tab → jalankan animasi indikator
    mainNavIndexNotifier.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final newIndex = mainNavIndexNotifier.value;
    _indicatorAnimation = Tween<double>(
      begin: _previousIndex.toDouble(),
      end: newIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _indicatorController,
      curve: Curves.easeOutCubic,
    ));
    _indicatorController.forward(from: 0);
    _previousIndex = newIndex;
  }

  @override
  void dispose() {
    mainNavIndexNotifier.removeListener(_onTabChanged);
    _indicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<int>(
      valueListenable: mainNavIndexNotifier,
      builder: (context, currentIndex, child) {
        return Scaffold(
          extendBody: true, // Body scroll di belakang navbar transparan
          body: _screens[currentIndex],

          bottomNavigationBar: SafeArea(
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                // Shadow ganda untuk efek kedalaman liquid glass
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : const Color(0xFF0D2B6B))
                        .withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: BackdropFilter(
                  // Blur kuat → efek kaca (glass)
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: AnimatedBuilder(
                    animation: _indicatorController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(36),
                          // Gradient liquid glass — dari biru gelap transparan
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    const Color(0xFF1A2A4A).withOpacity(0.92),
                                    const Color(0xFF0E1B30).withOpacity(0.95),
                                  ]
                                : [
                                    const Color(0xFF14325E).withOpacity(0.88),
                                    const Color(0xFF0B1D3A).withOpacity(0.92),
                                  ],
                          ),
                          // Border tipis putih → efek kaca terkena cahaya
                          border: Border.all(
                            color: Colors.white.withOpacity(isDark ? 0.08 : 0.18),
                            width: 1,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth = constraints.maxWidth / 5;

                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // ═══ LIQUID GLASS INDICATOR ═══
                                // Bulatan transparan yang bergerak smooth antar tab
                                Positioned(
                                  left: (_indicatorAnimation.value * itemWidth) +
                                      (itemWidth / 2) - 28,
                                  child: Container(
                                    width: 56,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      // Efek glow liquid glass
                                      color: Colors.white.withOpacity(0.14),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 0.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF4A90D9)
                                              .withOpacity(0.15),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // ═══ NAV ITEMS ═══
                                Row(
                                  children: [
                                    Expanded(child: _buildNavItem(
                                      Icons.chat_bubble_outline_rounded,
                                      Icons.chat_bubble_rounded,
                                      'Chat',
                                      0,
                                      currentIndex,
                                    )),
                                    Expanded(child: _buildNavItem(
                                      Icons.groups_outlined,
                                      Icons.groups_rounded,
                                      'Grup',
                                      1,
                                      currentIndex,
                                    )),
                                    Expanded(child: _buildNavItem(
                                      Icons.shopping_bag_outlined,
                                      Icons.shopping_bag_rounded,
                                      'Beli',
                                      2,
                                      currentIndex,
                                    )),
                                    Expanded(child: _buildNavItem(
                                      Icons.call_outlined,
                                      Icons.call_rounded,
                                      'Panggilan',
                                      3,
                                      currentIndex,
                                    )),
                                    Expanded(child: _buildNavItem(
                                      Icons.person_outline_rounded,
                                      Icons.person_rounded,
                                      'Profil',
                                      4,
                                      currentIndex,
                                    )),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    IconData icon,
    IconData activeIcon,
    String label,
    int index,
    int currentIndex,
  ) {
    final isActive = index == currentIndex;

    return GestureDetector(
      onTap: () => mainNavIndexNotifier.value = index,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            // Icon dengan animasi scale saat aktif
            AnimatedScale(
              scale: isActive ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Icon(
                isActive ? activeIcon : icon,
                size: 24,
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 4),
            // Label dengan animasi opacity
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.55),
              ),
              child: Text(label),
            ),
          ],
        ),
    );
  }
}
