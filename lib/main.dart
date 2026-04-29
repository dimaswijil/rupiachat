import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';

import 'services/chat_service.dart';
import 'services/call_notification_service.dart';
import 'utils/colors.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav_screen.dart';

// Handler notifikasi saat app di background (wajib di luar class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Notif background: ${message.notification?.title}');
}

// Global Notifier untuk Dark Mode
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// Global Notifier untuk Tab Navigation agar tidak reset saat ganti tema
final ValueNotifier<int> mainNavIndexNotifier = ValueNotifier(0);

// Global Navigator Key untuk sinkronisasi Call Notification State System-wide
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id', null);

  // Load preferred theme from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // 1. Init Firebase — HANYA untuk notifikasi FCM (Wajib await)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 3. Setup notifikasi background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Minta izin notifikasi dari user (JANGAN DIAWAIT, agar jika limitasi Apple terjadi tidak bikin hang)
    FirebaseMessaging.instance.requestPermission().then((_) {
      // 5. Foreground notification
      FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }).catchError((e) { debugPrint('FCM Permission Error: $e'); return null; });

    // 6. Listen token refresh → update ke server
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');
      if (authToken != null && authToken.isNotEmpty) {
        final chat = ChatService();
        chat.setToken(authToken);
        chat.updateFcmToken(newToken);
      }
    });

  } catch (e) {
    debugPrint("🔥 Firebase Init Gagal (Bisa diabaikan jika di iOS gratis): $e");
  }

  // 8. Inisialisasi listener panggilan masuk
  CallNotificationService().initialize();

  // 7. Langsung render aplikasi agar tidak putih/stuck!
  runApp(const RupiaChatApp());
}

class RupiaChatApp extends StatelessWidget {
  const RupiaChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'RupiaChat',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: RupiaColors.primary),
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: RupiaColors.primary,
              brightness: Brightness.dark,
            ),
          ),
          // Definisikan routes agar navigasi '/' lebih pasti
          routes: {
            '/': (context) => const AuthWrapper(),
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const MainNavScreen(),
          },
        );
      },
    );
  }
}

// Wrapper untuk menentukan halaman awal (Login atau Home)
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkLogin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        if (snapshot.data == true) {
          return const MainNavScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

// ── Splash Screen ─────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: RupiaColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'RupiaChat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Chat & Bayar dalam Satu App',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Color(0xFFF4A900)),
          ],
        ),
      ),
    );
  }
}
