import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:midtrans_sdk/midtrans_sdk.dart';
import '../config/api_config.dart';

// ─────────────────────────────────────────────────────────────────
//  MidtransService — Singleton untuk mengelola Midtrans SDK
//
//  Alur:
//  1. Flutter minta snap_token ke Laravel (via WalletService)
//  2. Token tersebut dikirim ke SDK Midtrans via startPaymentUiFlow
//  3. SDK membuka halaman pembayaran (Snap UI)
//  4. Callback otomatis dijalankan saat transaksi selesai
// ─────────────────────────────────────────────────────────────────

class MidtransService {
  static final MidtransService _instance = MidtransService._internal();
  factory MidtransService() => _instance;
  MidtransService._internal();

  MidtransSDK? _midtrans;
  bool _isInitialized = false;
  bool _isInitializing = false;

  /// Client Key Midtrans Sandbox (ganti dengan milik Anda)
  /// Untuk production, ganti prefix ke "Mid-client-xxx"
  static const _clientKey = 'SB-Mid-client-x5RmZ34A2KiPlLDz';

  /// Merchant Base URL — pointing ke Laravel API
  /// SDK membutuhkan ini untuk internal charge (opsional)
  static String get _merchantBaseUrl => '${ApiConfig.baseUrl}/api/';

  /// Inisialisasi SDK Midtrans
  /// Panggil sekali di awal saat user masuk ke halaman payment
  Future<void> initialize({
    Function(TransactionResult)? onTransactionFinished,
  }) async {
    if (_isInitialized && _midtrans != null) {
      // SDK sudah diinisialisasi, cukup update callback jika ada
      if (onTransactionFinished != null) {
        _midtrans!.setTransactionFinishedCallback(onTransactionFinished);
      }
      return;
    }

    // Cegah concurrent init
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      _midtrans = await MidtransSDK.init(
        config: MidtransConfig(
          clientKey: _clientKey,
          merchantBaseUrl: _merchantBaseUrl,
          colorTheme: ColorTheme(
            colorPrimary: const Color(0xFF1A3C8F),      // RupiaColors.primary
            colorPrimaryDark: const Color(0xFF0D2B6B),   // Darker variant
            colorSecondary: const Color(0xFFF4A900),     // RupiaColors.gold
          ),
        ),
      );

      // Set default callback
      if (onTransactionFinished != null) {
        _midtrans!.setTransactionFinishedCallback(onTransactionFinished);
      }

      _isInitialized = true;
      debugPrint('[MidtransService] SDK berhasil diinisialisasi');
    } on PlatformException catch (e) {
      // Native Android SDK gagal load (ClassNotFoundException, dll)
      debugPrint('[MidtransService] PlatformException saat init SDK: $e');
      _isInitialized = false;
      rethrow; // biarkan caller handle
    } catch (e) {
      debugPrint('[MidtransService] Gagal inisialisasi SDK: $e');
      _isInitialized = false;
      rethrow; // biarkan caller handle
    } finally {
      _isInitializing = false;
    }
  }

  /// Buka halaman pembayaran Snap Midtrans
  /// [snapToken] didapat dari Laravel API (WalletService.generateTopUpToken)
  void startPayment(String snapToken) {
    if (_midtrans == null) {
      debugPrint('[MidtransService] SDK belum diinisialisasi! Panggil initialize() dulu.');
      return;
    }
    _midtrans!.startPaymentUiFlow(token: snapToken);
  }

  /// Set ulang callback transaksi (mis. saat pindah halaman)
  void setTransactionCallback(Function(TransactionResult) callback) {
    _midtrans?.setTransactionFinishedCallback(callback);
  }

  /// Bersihkan resource SDK
  void dispose() {
    _midtrans?.removeTransactionFinishedCallback();
    _isInitialized = false;
    debugPrint('[MidtransService] SDK disposed');
  }
}
