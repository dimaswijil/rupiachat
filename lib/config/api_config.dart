// ─────────────────────────────────────────────────────────
//  API Config — Auto-Discovery Server (v2)
//
//  Otomatis menemukan server Laravel di jaringan lokal.
//  Tidak perlu ganti IP manual saat WiFi berubah!
//
//  Cara kerja:
//  1. Coba IP terakhir yang berhasil (dari cache)
//  2. Coba daftar IP yang sering dipakai (known IPs)
//  3. Scan SEMUA subnet dari SEMUA network interface
//  4. Simpan IP yang berhasil ke cache
// ─────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  /// Port server Laravel
  static const port = 8000;

  /// Daftar IP server yang pernah dipakai / sering dipakai
  /// Tambahkan IP Mac kamu di sini agar dicoba pertama
  static const _knownServerIps = [
    '192.168.112.18', // Mac IP saat ini
    '192.168.1.5',    // Mac IP lama
  ];

  /// Key untuk SharedPreferences
  static const _cacheKey = 'server_ip_cache';

  /// Base URL yang aktif (diisi saat init)
  static String _baseUrl = 'http://localhost:$port';

  /// --- KONFIGURASI RAILWAY CLOUD ---
  static const bool useRailway = true; // Set false jika ingin kembali pakai IP Lokal (Auto-Discovery)
  static const String railwayUrl = 'https://rupiachat-api-production.up.railway.app'; // URL Railway Production
  /// -------------------------

  /// Getter untuk base URL
  static String get baseUrl => _baseUrl;

  /// Inisialisasi — panggil di main() sebelum runApp
  static Future<void> init() async {
    // 0. Cek apakah menggunakan Railway
    if (useRailway) {
      _baseUrl = railwayUrl;
      debugPrint('✅ Menggunakan URL Railway publik: $_baseUrl');
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // 1. Coba IP terakhir yang berhasil (paling cepat)
    final cachedIp = prefs.getString(_cacheKey);
    if (cachedIp != null && await _isServerReachable(cachedIp)) {
      _baseUrl = 'http://$cachedIp:$port';
      debugPrint('✅ Server ditemukan di cached IP: $cachedIp');
      return;
    }

    // Cached IP gagal → hapus cache basi agar tidak dipakai lagi
    if (cachedIp != null) {
      debugPrint('⚠️ Cached IP $cachedIp sudah tidak valid, menghapus cache...');
      await prefs.remove(_cacheKey);
    }

    // 2. Coba semua known IPs secara parallel
    debugPrint('🔍 Mencoba known server IPs...');
    final knownResults = await Future.wait(
      _knownServerIps.map((ip) async {
        if (await _isServerReachable(ip)) return ip;
        return null;
      }),
    );
    final knownHit = knownResults.where((r) => r != null).firstOrNull;
    if (knownHit != null) {
      _baseUrl = 'http://$knownHit:$port';
      await prefs.setString(_cacheKey, knownHit);
      debugPrint('✅ Server ditemukan di known IP: $knownHit');
      return;
    }

    // 3. Scan SEMUA subnet dari semua network interface
    final subnets = await _getAllSubnets();
    debugPrint('🔍 Scanning ${subnets.length} subnet(s): $subnets');
    for (final subnet in subnets) {
      final foundIp = await _scanSubnet(subnet);
      if (foundIp != null) {
        _baseUrl = 'http://$foundIp:$port';
        await prefs.setString(_cacheKey, foundIp);
        debugPrint('✅ Server ditemukan via scan: $foundIp');
        return;
      }
    }

    // 4. Fallback: pakai known IP pertama
    if (_knownServerIps.isNotEmpty) {
      _baseUrl = 'http://${_knownServerIps.first}:$port';
      debugPrint('⚠️ Server tidak ditemukan, pakai known IP: ${_knownServerIps.first}');
    } else {
      debugPrint('❌ Server tidak ditemukan di jaringan lokal');
    }
  }

  /// Cek apakah server bisa diakses di IP tertentu
  /// PENTING: Harus verifikasi response body, bukan hanya status code!
  /// Kalau hanya cek status 200-499, server lain di jaringan (yang return 401/404)
  /// bisa salah dianggap sebagai server Laravel → cached IP salah.
  static Future<bool> _isServerReachable(String ip) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client
          .getUrl(Uri.parse('http://$ip:$port/api/ping'))
          .timeout(const Duration(seconds: 4));
      final response = await request.close().timeout(const Duration(seconds: 4));
      
      // Baca response body dan verifikasi isinya
      final body = await response.transform(utf8.decoder).join();
      client.close();
      
      // Hanya return true jika response berisi {"status":"ok"}
      // Ini memastikan benar-benar server Laravel kita, bukan server lain
      final isOurServer = response.statusCode == 200 && body.contains('"status"') && body.contains('"ok"');
      if (!isOurServer) {
        debugPrint('❌ $ip:$port bukan server Laravel kita (status=${response.statusCode}, body=${body.substring(0, body.length.clamp(0, 100))})');
      }
      return isOurServer;
    } catch (_) {
      return false;
    }
  }

  /// Dapatkan SEMUA subnet dari semua network interface
  static Future<List<String>> _getAllSubnets() async {
    final subnets = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          // Terima semua private IP ranges
          if (ip.startsWith('192.168') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            final subnet = ip.substring(0, ip.lastIndexOf('.'));
            subnets.add(subnet);
            debugPrint('📡 Interface ${iface.name}: $ip (subnet: $subnet.*)');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Gagal list network interfaces: $e');
    }
    return subnets.toList();
  }

  /// Scan subnet untuk menemukan server Laravel
  static Future<String?> _scanSubnet(String subnet) async {
    // Scan semua 254 host secara parallel dalam batch
    const batchSize = 50;

    for (int start = 1; start < 255; start += batchSize) {
      final futures = <Future<String?>>[];
      final end = (start + batchSize).clamp(1, 255);

      for (int i = start; i < end; i++) {
        final ip = '$subnet.$i';
        futures.add(_checkHost(ip));
      }

      final results = await Future.wait(futures);
      final found = results.where((r) => r != null).firstOrNull;
      if (found != null) return found;
    }
    return null;
  }

  /// Cek satu host apakah ada server Laravel
  static Future<String?> _checkHost(String ip) async {
    try {
      final socket = await Socket.connect(ip, port,
          timeout: const Duration(milliseconds: 800));
      socket.destroy();
      // Port terbuka, verifikasi apakah benar server Laravel
      if (await _isServerReachable(ip)) {
        return ip;
      }
    } catch (_) {}
    return null;
  }

  /// Manual set URL (untuk settings screen)
  static Future<void> setManualUrl(String ip) async {
    _baseUrl = 'http://$ip:$port';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, ip);
  }

  /// Reset cache dan re-discover
  static Future<void> rediscover() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await init();
  }
}
