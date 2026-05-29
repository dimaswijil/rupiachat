import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────
//  XenditService — Singleton untuk mengelola pembayaran via Xendit
//
//  Alur:
//  1. Flutter minta invoice_url ke Laravel (via PurchaseService)
//  2. Token/URL tersebut dikirim ke XenditService via openInvoiceUrl
//  3. Aplikasi membuka halaman pembayaran di dalam In-App WebView
// ─────────────────────────────────────────────────────────────────

class XenditService {
  static final XenditService _instance = XenditService._internal();
  factory XenditService() => _instance;
  XenditService._internal();

  /// Membuka URL Invoice Xendit dalam In-App WebView
  Future<void> openInvoiceUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
      } else {
        debugPrint('⚠️ [XenditService] Tidak dapat membuka URL: $url');
      }
    } catch (e) {
      debugPrint('⚠️ [XenditService] Gagal membuka URL: $e');
    }
  }
}
