import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  final _supabase = Supabase.instance.client;

  /// Mengunggah file (PDF/Audio) ke Supabase Storage dan mengembalikan URL publik permanen.
  Future<String> uploadFile({required String filePath, required String bucketName}) async {
    try {
      final file = File(filePath);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${filePath.split('/').last}';

      // 1. Unggah file biner ke bucket Supabase
      await _supabase.storage.from(bucketName).upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // 2. Ambil URL publik permanen dari file yang telah diunggah
      final String publicUrl = _supabase.storage.from(bucketName).getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      throw Exception('Gagal mengunggah ke Supabase Storage: $e');
    }
  }
}
