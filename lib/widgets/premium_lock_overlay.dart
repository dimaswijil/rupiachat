import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/purchase_service.dart';
import '../main.dart';

class PremiumLockOverlay extends StatelessWidget {
  final Widget child;
  final String featureSlug;
  final String title;
  final String message;

  const PremiumLockOverlay({
    super.key,
    required this.child,
    required this.featureSlug,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: PurchaseService().activeFeaturesNotifier,
      builder: (context, activeFeatures, _) {
        final isUnlocked = PurchaseService().isFeatureUnlocked(featureSlug);
        
        if (isUnlocked) {
          return child;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Background screen
            child,
            
            // Blur effect
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                  child: Container(
                    color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            
            // Lock UI
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Container(
                  padding: const EdgeInsets.all(28.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.amber,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD97706).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              // Navigasi ke tab Beli (index 2)
                              mainNavIndexNotifier.value = 2;
                            },
                            child: const Text(
                              'Buka Fitur VIP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
