import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final double size;
  final String? photoUrl;
  final bool interactive;
  final String? heroTag;

  const AvatarWidget({
    super.key, 
    required this.name, 
    this.size = 48,
    this.photoUrl,
    this.interactive = false,
    this.heroTag,
  });

  Color get _bg { const c = [Color(0xFFE6F1FB),Color(0xFFE1F5EE),Color(0xFFFAECE7),Color(0xFFFBEAF0),Color(0xFFEAF3DE)]; return c[name.codeUnitAt(0) % c.length]; }
  Color get _fg { const c = [Color(0xFF185FA5),Color(0xFF0F6E56),Color(0xFF993C1D),Color(0xFF993556),Color(0xFF3B6D11)]; return c[name.codeUnitAt(0) % c.length]; }

  @override
  Widget build(BuildContext context) {
    Widget avatar = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: photoUrl != null ? null : _bg, 
        shape: BoxShape.circle,
        image: photoUrl != null ? DecorationImage(
          image: NetworkImage(photoUrl!),
          fit: BoxFit.cover,
        ) : null,
      ),
      alignment: Alignment.center,
      child: photoUrl != null ? null : Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: _fg, fontWeight: FontWeight.w700, fontSize: size * 0.35)
      ),
    );

    if (!interactive || photoUrl == null) return avatar;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false, // Make background transparent
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (context, animation, secondaryAnimation) {
              return FadeTransition(
                opacity: animation,
                child: Scaffold(
                  backgroundColor: Colors.black.withOpacity(0.9),
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),
                  body: Center(
                    child: InteractiveViewer(
                      child: heroTag != null 
                        ? Hero(tag: heroTag!, child: Image.network(photoUrl!))
                        : Image.network(photoUrl!),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      child: heroTag != null ? Hero(tag: heroTag!, child: avatar) : avatar,
    );
  }
}
