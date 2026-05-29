import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class PhotoConfirmScreen extends StatefulWidget {
  final String imagePath;
  final String title;

  const PhotoConfirmScreen({
    super.key,
    required this.imagePath,
    required this.title,
  });

  @override
  State<PhotoConfirmScreen> createState() => _PhotoConfirmScreenState();
}

class _PhotoConfirmScreenState extends State<PhotoConfirmScreen> {
  final _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _send() {
    Navigator.of(context).pop({
      'confirmed': true,
      'caption': _captionController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop({'confirmed': false}),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. Gambar Utama di Tengah dengan InteractiveViewer untuk Zooming
          Positioned.fill(
            child: Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 3.0,
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // 2. Panel Input Caption Float di Bawah
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Text Field Caption
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Tambahkan keterangan...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tombol Kirim Bundar Premium
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: RupiaColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: RupiaColors.primary,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
