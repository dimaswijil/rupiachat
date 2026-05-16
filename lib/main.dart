import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';

import 'config/api_config.dart';
import 'services/chat_service.dart';
import 'services/call_notification_service.dart';
import 'utils/colors.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_nav_screen.dart';

import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

// Handler notifikasi saat app di background (wajib di luar class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Notif background: ${message.notification?.title}');
  
  final data = message.data;
  
  // Deteksi jika tipe pesan adalah panggilan masuk
  if (data['type'] == 'incoming_call' || data['type'] == 'incoming_group_call') {
    final isVideo = data['call_type'] == 'video';
    
    final callKitParams = CallKitParams(
      id: data['channel_name'] ?? 'call_${DateTime.now().millisecondsSinceEpoch}',
      nameCaller: data['caller_name'] ?? 'Unknown',
      appName: 'RupiaChat',
      avatar: data['caller_photo'] ?? '',
      handle: isVideo ? 'Panggilan Video Masuk' : 'Panggilan Suara Masuk',
      type: isVideo ? 1 : 0, 
      textAccept: 'Terima',
      textDecline: 'Tolak',
      duration: 60000,
      extra: Map<String, dynamic>.from(data),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0A0E21',
        actionColor: '#4CAF50',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  } else if (data['signal_type'] == 'cancel' || data['signal_type'] == 'end') {
     // Jika call di-cancel/diakhiri oleh pemanggil sebelum diangkat
     await FlutterCallkitIncoming.endAllCalls();
  }
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

  // Auto-discover server Laravel di jaringan lokal
  await ApiConfig.init();

  // Load preferred theme from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // 1. Init Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. Setup handler notifikasi background (wajib top-level function)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Listen token refresh → update ke server
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');
      if (authToken != null && authToken.isNotEmpty) {
        final chat = ChatService();
        chat.setToken(authToken);
        chat.updateFcmToken(newToken);
      }
    });

    // 3b. Paksa update token saat startup jika sudah login
    final authToken = prefs.getString('auth_token');
    if (authToken != null && authToken.isNotEmpty) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          final chat = ChatService();
          chat.setToken(authToken);
          chat.updateFcmToken(token);
          debugPrint('✅ FCM Token disinkronkan saat startup');
        }
      } catch (e) {
        debugPrint('⚠️ Gagal sinkronisasi FCM Token saat startup: $e');
      }
    }

  } catch (e) {
    debugPrint("🔥 Firebase Init Gagal: $e");
  }

  // 4. Inisialisasi Notification Service (channel + listeners + permissions)
  // HARUS await agar notification channel sudah ada sebelum app jalan
  await CallNotificationService().initialize();

  // 5. Render aplikasi
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
// PENTING: Tidak cukup hanya cek apakah token ada di SharedPreferences.
// Harus validasi ke server apakah token masih aktif.
// Kalau tidak, token lama (misalnya setelah reset password) akan bikin
// app langsung masuk Home → semua API return 401.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return false;

    // Validasi token ke server — cek apakah masih valid
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client
          .getUrl(Uri.parse('${ApiConfig.baseUrl}/api/users'))
          .timeout(const Duration(seconds: 12));
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Accept', 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 12));
      client.close();

      if (response.statusCode == 200) {
        // Token masih valid
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token secara eksplisit sudah kadaluarsa atau tidak valid → logout
        debugPrint('⚠️ Token invalid (${response.statusCode}), clearing auth data...');
        await prefs.remove('auth_token');
        await prefs.remove('user_id');
        return false;
      } else {
        // Server error (misal 500, 502 Bad Gateway) → jangan hapus token.
        // Anggap user masih punya token yang valid, biarkan masuk agar tidak ter-logout saat server/ngrok down sementara.
        debugPrint('⚠️ Server error (${response.statusCode}) saat validasi token, asumsikan token valid.');
        return true;
      }
    } catch (e) {
      // Network error → tetap izinkan masuk (nanti error di dalam)
      // Agar app tidak stuck di login saat offline tapi punya token valid
      debugPrint('⚠️ Token validation failed (network): $e');
      return true;
    }
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
