import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
//  Semua warna brand RupiaChat ada di sini
//  Kalau mau ganti warna, cukup edit file ini
// ─────────────────────────────────────────────

class RupiaColors {
  static Color primary       = const Color(0xFF1A3C8F); // biru utama (non-const)
  static const gold          = Color(0xFFF4A900); // emas untuk payment
  static const success       = Color(0xFF0F6E56); // hijau untuk pemasukan
  static const danger        = Color(0xFF993C1D); // merah untuk pengeluaran
  static const bg            = Color(0xFFF5F7FA); // background halaman (Light Mode)
  
  // Dark Mode Background
  static const bgDark        = Color(0xFF121212);
  static const cardDark      = Color(0xFF1E1E1E);

  static const textPrimary   = Color(0xFF1A1A2E); // teks utama
  static const textSecondary = Color(0xFF6B7280); // teks abu-abu
  static const textHint      = Color(0xFFB0B7C3); // placeholder

  static Future<void> loadThemeColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorHex = prefs.getString('theme_primary_color');
      if (colorHex != null) {
        final value = int.tryParse(colorHex);
        if (value != null) {
          primary = Color(value);
        }
      }
    } catch (_) {}
  }

  static Future<void> saveThemeColor(Color color) async {
    primary = color;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_primary_color', color.value.toString());
    } catch (_) {}
  }
}
