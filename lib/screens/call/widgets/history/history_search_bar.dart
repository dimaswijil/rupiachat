import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../utils/colors.dart';

class HistorySearchBar extends StatelessWidget {
  final bool isDark;
  final ValueChanged<String> onChanged;

  const HistorySearchBar({
    super.key,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [RupiaColors.primary, RupiaColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(isDark ? 0.1 : 0.3),
                width: 1,
              ),
            ),
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Cari panggilan...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
