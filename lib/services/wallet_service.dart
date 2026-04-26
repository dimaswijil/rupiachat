import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../main.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;

  static const _baseUrl = 'http://192.168.1.5:8000';
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

  Future<double> getBalance() async {
    try {
      await _ensureToken();
      final response = await _dio.get('/api/wallet');
      return double.parse(response.data['balance'].toString());
    } catch (e) {
      print('Get Balance Error: $e');
      return 0.0;
    }
  }

  Future<String?> generateTopUpToken(double amount) async {
    try {
      await _ensureToken();
      final response = await _dio.post('/api/wallet/topup', data: {
        'amount': amount,
      });
      return response.data['redirect_url']; // URL for Midtrans Snap Simulator
    } catch (e) {
      print('Top Up Error: $e');
      return null;
    }
  }
}
