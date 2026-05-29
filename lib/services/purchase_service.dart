import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../main.dart';
import '../config/api_config.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;

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

  PurchaseService._internal() {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          debugPrint('[PurchaseService] 401 Unauthenticated — auto logout');
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

  /// Get current wallet balance
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

  /// Request Invoice URL from Laravel for Top Up via Xendit
  Future<String?> generateTopUpInvoice(double amount) async {
    try {
      await _ensureToken();
      final response = await _dio.post('/api/wallet/topup', data: {
        'amount': amount,
      });
      return response.data['invoice_url'];
    } catch (e) {
      debugPrint('Top Up Error: $e');
      return null;
    }
  }

  /// Get USD to IDR exchange rate and updated_at
  /// Returns {'usd_idr': 16000.0, 'updated_at': '...'} or null
  Future<Map<String, dynamic>?> getExchangeRate() async {
    try {
      await _ensureToken();
      final response = await _dio.get('/api/exchange-rate');
      return {
        'usd_idr': double.parse((response.data['usd_idr'] ?? response.data['rate']).toString()),
        'updated_at': response.data['updated_at'] ?? '',
      };
    } catch (e) {
      debugPrint('Get Exchange Rate Error: $e');
      return null;
    }
  }

  /// Purchase a feature using wallet balance
  /// Returns {'success': true, 'message': '...'} or {'success': false, 'error': '...'}
  Future<Map<String, dynamic>> buyFeature({
    required String featureSlug,
    required String featureName,
    required double price,
  }) async {
    try {
      await _ensureToken();
      final response = await _dio.post('/api/purchases', data: {
        'feature_slug': featureSlug,
        'feature_name': featureName,
        'price': price,
      });
      return {
        'success': true,
        'message': response.data['message'] ?? 'Pembelian berhasil',
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal membeli fitur';
      return {'success': false, 'error': msg};
    } catch (e) {
      debugPrint('Buy Feature Error: $e');
      return {'success': false, 'error': 'Terjadi kesalahan'};
    }
  }

  /// Fetch user's purchase history
  Future<List<Map<String, dynamic>>> getPurchases() async {
    try {
      await _ensureToken();
      final response = await _dio.get('/api/purchases/my');
      final List<dynamic> data = response.data['purchases'] ?? [];
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      debugPrint('Get Purchases Error: $e');
      return [];
    }
  }

  /// ValueNotifier to track active features system-wide
  final ValueNotifier<List<String>> activeFeaturesNotifier = ValueNotifier<List<String>>([]);

  /// Check if a specific feature is unlocked (VIP unlocks everything)
  bool isFeatureUnlocked(String slug) {
    final features = activeFeaturesNotifier.value;
    if (features.contains('vip_member')) return true;
    return features.contains(slug);
  }

  /// Fetch active features of the user
  Future<List<String>> getActiveFeatures() async {
    try {
      await _ensureToken();
      final response = await _dio.get('/api/features/my');
      final List<dynamic> data = response.data['features'] ?? [];
      final features = data.cast<String>();
      activeFeaturesNotifier.value = features;
      return features;
    } catch (e) {
      debugPrint('Get Active Features Error: $e');
      return activeFeaturesNotifier.value;
    }
  }
}
