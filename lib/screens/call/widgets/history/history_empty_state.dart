import 'package:flutter/material.dart';
import '../../../../utils/colors.dart';

class HistoryEmptyState extends StatelessWidget {
  final bool isDark;

  const HistoryEmptyState({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : RupiaColors.primary.withOpacity(0.08),
            ),
            child: Icon(
              Icons.call_rounded,
              size: 36,
              color: isDark ? Colors.white24 : RupiaColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada riwayat panggilan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : RupiaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Panggilan suara dan video\nakan muncul di sini',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white38 : RupiaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
