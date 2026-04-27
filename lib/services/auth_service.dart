import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/api_config.dart';

class AuthService {
  // Base URL diambil dari ApiConfig (satu tempat untuk semua service)
  static const _baseUrl = ApiConfig.baseUrl;
  
  final _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  Future<Map<String, dynamic>?> get currentUser async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');
    if (uid == null) return null;
    return {
      'uid'  : uid,
      'name' : prefs.getString('user_name'),
      'email': prefs.getString('user_email'),
      'photo_url': prefs.getString('user_photo'),
    };
  }

  Future<String?> get currentUid async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  Future<String?> get currentToken async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<String?> get currentName async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  Future<String?> get currentEmail async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  Future<String?> get currentPhoto async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_photo');
  }

  Future<String?> get currentPhone async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_phone');
  }

  // UPDATE PROFILE NAME, EMAIL, AND PHONE
  Future<String?> updateProfile(String name, String email, String phone) async {
    try {
      final token = await currentToken;
      final res = await _dio.post('/api/user/update-profile', 
        data: {
          'name': name,
          'email': email,
          'phone': phone,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'})
      );

      final userData = res.data['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', userData['name']);
      await prefs.setString('user_phone', userData['phone'] ?? '');
      
      return null; // sukses
    } on DioException catch (e) {
      return _parseError(e);
    }
  }

  // UPDATE PROFILE PHOTO
  Future<String?> updateProfilePhoto(String filePath) async {
    try {
      final token = await currentToken;
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(filePath),
      });

      final res = await _dio.post('/api/user/update-photo', 
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'})
      );

      final newPhotoUrl = res.data['photo_url'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_photo', newPhotoUrl);
      
      return null; // sukses
    } on DioException catch (e) {
      return _parseError(e);
    }
  }

  // Helper: ambil FCM token, return null jika gagal (mis. di iOS Simulator)
  Future<String?> _getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      print('FCM getToken gagal (normal di iOS Simulator): $e');
      return null;
    }
  }

  // ── REQUEST OTP ──────────────────────────────────────────
  // Kirim data pendaftaran ke server untuk validasi + generate OTP
  Future<Map<String, dynamic>> requestOtp(String name, String phone, String email, String password) async {
    try {
      final res = await _dio.post('/api/auth/request-otp', data: {
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
      });
      return {'success': true, 'expires_in': res.data['expires_in'] ?? 300};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    }
  }

  // ── VERIFY OTP ──────────────────────────────────────────
  // Kirim kode OTP ke server untuk diverifikasi + buat akun
  Future<String?> verifyOtp(String email, String otpCode) async {
    try {
      final fcmToken = await _getFcmToken();
      final res = await _dio.post('/api/auth/verify-otp', data: {
        'email': email,
        'otp_code': otpCode,
        'fcm_token': fcmToken,
      });
      await _saveUserData(res.data);
      return null; // sukses
    } on DioException catch (e) {
      return _parseError(e);
    }
  }

  // ── RESEND OTP ──────────────────────────────────────────
  // Kirim ulang kode OTP (memanggil requestOtp lagi)
  Future<Map<String, dynamic>> resendOtp(String name, String phone, String email, String password) async {
    return requestOtp(name, phone, email, password);
  }

  // ── FORGOT PASSWORD ───────────────────────────────────────
  Future<Map<String, dynamic>> requestPasswordResetOtp(String email) async {
    try {
      final res = await _dio.post('/api/auth/forgot-password', data: {
        'email': email,
      });
      return {'success': true, 'expires_in': res.data['expires_in'] ?? 300};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    }
  }

  Future<String?> resetPassword(String email, String otpCode, String newPassword) async {
    try {
      await _dio.post('/api/auth/reset-password', data: {
        'email': email,
        'otp_code': otpCode,
        'password': newPassword,
      });
      return null; // sukses
    } on DioException catch (e) {
      return _parseError(e);
    }
  }

  // ── DAFTAR LANGSUNG (Legacy) ────────────────────────────
  Future<String?> register(String name, String phone, String email, String password) async {
    try {
      final fcmToken = await _getFcmToken();
      final res = await _dio.post('/api/register', data: {
        'name': name, 'phone': phone, 'email': email,
        'password': password, 'password_confirmation': password,
        'fcm_token': fcmToken,
      });
      await _saveUserData(res.data);
      return null;
    } on DioException catch (e) { return _parseError(e); }
  }

  Future<String?> login(String email, String password) async {
    try {
      final fcmToken = await _getFcmToken();
      final res = await _dio.post('/api/login', data: {
        'email': email, 'password': password,
        'fcm_token': fcmToken,
      });
      await _saveUserData(res.data);
      return null;
    } on DioException catch (e) {
      return _parseError(e);
    }
  }

  Future<void> logout() async {
    try {
      final token = await currentToken;
      if (token != null) {
        await _dio.post('/api/logout',
            options: Options(headers: {'Authorization': 'Bearer $token'}));
      }
    } catch (_) {
    } finally {
      await _clearUserData();
    }
  }

  Future<void> _saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', data['token']);
    await prefs.setString('user_id',    data['user']['id'].toString());
    await prefs.setString('user_name',  data['user']['name']);
    await prefs.setString('user_email', data['user']['email']);
    await prefs.setString('user_phone', data['user']['phone'] ?? '');
    await prefs.setString('user_photo', data['user']['photo_url'] ?? '');
  }

  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  String _parseError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Koneksi ke server timeout. Pastikan Laravel sudah jalan.';
    }
    if (e.response == null) return 'Tidak bisa terhubung ke server';
    final data = e.response!.data;
    if (data is Map<String, dynamic>) return data['message'] ?? 'Terjadi kesalahan';
    return 'Terjadi kesalahan (${e.response?.statusCode})';
  }
}
