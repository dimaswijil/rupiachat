import 'package:dio/dio.dart';
import '../services/auth_service.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;

  static const _baseUrl = 'http://192.168.112.18:8000';
  final _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  WalletService._internal();

  Future<void> _ensureToken() async {
    final auth = AuthService();
    final token = await auth.currentToken;
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
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
