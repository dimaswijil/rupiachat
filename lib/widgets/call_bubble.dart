import 'package:flutter/material.dart';
import '../utils/colors.dart';

/// Call Bubble — tampilan khusus untuk pesan panggilan (seperti WhatsApp)
class CallBubble extends StatelessWidget {
  final bool isMe;
  final bool isVideo;
  final String status; // 'answered', 'missed', 'declined'
  final int duration; // in seconds
  final String time;

  const CallBubble({
    super.key,
    required this.isMe,
    required this.isVideo,
    required this.status,
    required this.duration,
    required this.time,
  });

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _statusText() {
    switch (status) {
      case 'answered':
        final dur = _formatDuration(duration);
        return dur.isNotEmpty ? dur : 'Dijawab';
      case 'missed':
        return 'Tidak dijawab';
      case 'declined':
        return 'Ditolak';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isMissed = status == 'missed' || status == 'declined';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 6),
        decoration: BoxDecoration(
          color: isMe
              ? RupiaColors.primary
              : (isDarkMode ? RupiaColors.cardDark : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: isDarkMode ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Ikon lingkaran ──
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMe
                    ? Colors.white.withOpacity(0.15)
                    : (isDarkMode
                        ? Colors.white.withOpacity(0.08)
                        : RupiaColors.primary.withOpacity(0.1)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                    color: isMe
                        ? Colors.white
                        : (isMissed ? const Color(0xFFEF4444) : RupiaColors.primary),
                    size: 18,
                  ),
                  // Arrow indicator
                  Positioned(
                    top: 6, right: 6,
                    child: Icon(
                      isMissed
                          ? Icons.call_missed_rounded
                          : (isMe ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded),
                      size: 10,
                      color: isMe
                          ? Colors.white70
                          : (isMissed ? const Color(0xFFEF4444) : RupiaColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // ── Teks + waktu ──
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isVideo ? 'Panggilan Video' : 'Panggilan Suara',
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : (isDarkMode ? Colors.white : RupiaColors.textPrimary),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _statusText(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isMissed
                              ? const Color(0xFFEF4444)
                              : (isMe ? Colors.white60 : (isDarkMode ? Colors.white38 : RupiaColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Time inside bubble
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white54 : (isDarkMode ? Colors.white38 : RupiaColors.textHint),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(Icons.done_all, size: 13,
                            color: isMe ? Colors.white54 : RupiaColors.textHint),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
