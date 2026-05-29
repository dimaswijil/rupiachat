import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/colors.dart';

class ImageViewerDialog extends StatelessWidget {
  final String imageUrl;
  final String title;

  const ImageViewerDialog({
    super.key,
    required this.imageUrl,
    this.title = 'Gambar',
  });

  /// Static helper to easily show the premium image viewer
  static void show(BuildContext context, String imageUrl, {String title = 'Gambar'}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.9),
        pageBuilder: (context, _, __) => ImageViewerDialog(
          imageUrl: imageUrl,
          title: title,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Blur
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Colors.black.withOpacity(0.65),
                ),
              ),
            ),
          ),

          // Interactive Image Area
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60.0),
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    clipBehavior: Clip.none,
                    child: Hero(
                      tag: imageUrl,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: RupiaColors.primary,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_rounded,
                                color: Colors.white60,
                                size: 64,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Gagal memuat gambar',
                                style: TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Premium Header Controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    // Back/Close Button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    // Title/Sender Info
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Optional Actions (like Share/Download placeholders)
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.white, size: 24),
                      tooltip: 'Simpan Gambar',
                      onPressed: () {
                        // Notify user or offer future options
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Gambar berhasil disimpan ke galeri (Simulasi)'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
