import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../main.dart';
import '../config/api_config.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;

  static final _baseUrl = ApiConfig.baseUrl;
  final _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  WalletService._internal() {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          debugPrint('[WalletService] 401 Unauthenticated — auto logout');
          await _handleUnauthorized();
        }
        return handler.next(error);
      },
    ));
  }

  Future<void> _ensureToken() async {
    final auth = AuthService();
    final token = await auth.currentToken;
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  static bool _isHandlingUnauth = false;
  Future<void> _handleUnauthorized() async {
    if (_isHandlingUnauth) return;
    _isHandlingUnauth = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } finally {
      _isHandlingUnauth = false;
    }
  }

  /// Ambil saldo wallet user yang sedang login
  Future<double> getBalance() async {
    try {
      await _ensureToken();
      final response = await _dio.get('/api/wallet');
      return double.parse(response.data['balance'].toString());
    } catch (e) {
      debugPrint('Get Balance Error: $e');
      return 0.0;
    }
  }

  /// Request Snap Token dari Laravel untuk Top Up via Midtrans SDK
  /// Laravel mengembalikan {'snap_token': 'xxxxx'}
  Future<String?> generateTopUpToken(double amount) async {
    try {
      await _ensureToken();
      final response = await _dio.post('/api/wallet/topup', data: {
        'amount': amount,
      });
      return response.data['snap_token']; // Snap Token untuk Midtrans SDK
    } catch (e) {
      debugPrint('Top Up Error: $e');
      return null;
    }
  }

  /// Transfer saldo ke user lain
  /// [receiverId] = ID user penerima (dari daftar users)
  /// [amount] = jumlah transfer (min Rp 1.000)
  /// Return: {'success': true, 'balance': 123000} atau {'success': false, 'error': '...'}
  Future<Map<String, dynamic>> transfer({
    required String receiverId,
    required double amount,
  }) async {
    try {
      await _ensureToken();
      final response = await _dio.post('/api/wallet/transfer', data: {
        'receiver_id': receiverId,
        'amount': amount,
      });
      return {
        'success': true,
        'balance': double.parse(response.data['balance'].toString()),
        'message': response.data['message'] ?? 'Transfer berhasil',
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal transfer';
      return {'success': false, 'error': msg};
    } catch (e) {
      debugPrint('Transfer Error: $e');
      return {'success': false, 'error': 'Terjadi kesalahan'};
    }
  }

  /// Ambil riwayat transaksi wallet (top up, transfer masuk, transfer keluar)
  /// Return list of maps: [{id, amount, type, status, description, reference_user_name, created_at}, ...]
  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      await _ensureToken();
      final response = await _dio.get('/api/wallet/history');
      final List<dynamic> data = response.data['transactions'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('History Error: $e');
      return [];
    }
  }
}
