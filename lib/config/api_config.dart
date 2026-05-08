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

  /// Getter untuk base URL
  static String get baseUrl => _baseUrl;

  /// Inisialisasi — panggil di main() sebelum runApp
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Coba IP terakhir yang berhasil (paling cepat)
    final cachedIp = prefs.getString(_cacheKey);
    if (cachedIp != null && await _isServerReachable(cachedIp)) {
      _baseUrl = 'http://$cachedIp:$port';
      print('✅ Server ditemukan di cached IP: $cachedIp');
      return;
    }

    // 2. Coba semua known IPs secara parallel
    print('🔍 Mencoba known server IPs...');
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
      print('✅ Server ditemukan di known IP: $knownHit');
      return;
    }

    // 3. Scan SEMUA subnet dari semua network interface
    final subnets = await _getAllSubnets();
    print('🔍 Scanning ${subnets.length} subnet(s): $subnets');
    for (final subnet in subnets) {
      final foundIp = await _scanSubnet(subnet);
      if (foundIp != null) {
        _baseUrl = 'http://$foundIp:$port';
        await prefs.setString(_cacheKey, foundIp);
        print('✅ Server ditemukan via scan: $foundIp');
        return;
      }
    }

    // 4. Fallback: pakai cached IP atau known IP pertama
    if (cachedIp != null) {
      _baseUrl = 'http://$cachedIp:$port';
      print('⚠️ Server tidak ditemukan, pakai cached IP: $cachedIp');
    } else if (_knownServerIps.isNotEmpty) {
      _baseUrl = 'http://${_knownServerIps.first}:$port';
      print('⚠️ Server tidak ditemukan, pakai known IP: ${_knownServerIps.first}');
    } else {
      print('❌ Server tidak ditemukan di jaringan lokal');
    }
  }

  /// Cek apakah server bisa diakses di IP tertentu
  static Future<bool> _isServerReachable(String ip) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client
          .getUrl(Uri.parse('http://$ip:$port/api/ping'))
          .timeout(const Duration(seconds: 4));
      final response = await request.close().timeout(const Duration(seconds: 4));
      client.close();
      return response.statusCode >= 200 && response.statusCode < 500;
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
            print('📡 Interface ${iface.name}: $ip (subnet: $subnet.*)');
          }
        }
      }
    } catch (e) {
      print('⚠️ Gagal list network interfaces: $e');
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
