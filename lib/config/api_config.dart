// ─────────────────────────────────────────────────────────
//  API Config — Satu tempat untuk mengatur Base URL
//
//  Pakai hostname ".local" agar tidak perlu ganti IP
//  setiap kali berpindah jaringan WiFi.
//
//  Cara kerja:
//  - Mac kamu punya nama "MacBook-Pro"
//  - Nama ini otomatis bisa diakses via "MacBook-Pro.local"
//    oleh semua device yang ada di jaringan WiFi yang sama
//  - Ini menggunakan protokol mDNS/Bonjour (bawaan Apple)
//  - Tidak peduli IP berubah, nama ini TETAP sama
//
//  Jika .local tidak bekerja (jarang terjadi di beberapa
//  router), ganti ke IP manual di bawah ini:
//  static const baseUrl = 'http://192.168.x.x:8000';
// ─────────────────────────────────────────────────────────

class ApiConfig {
  /// Base URL untuk semua API request
  static const baseUrl = 'http://MacBook-Pro.local:8000';

  /// Port server Laravel
  static const port = 8000;
}
