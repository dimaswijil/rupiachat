import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/avatar_widget.dart';
import '../../../../utils/colors.dart';

class HistoryCallTile extends StatelessWidget {
  final Map<String, dynamic> call;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const HistoryCallTile({
    super.key,
    required this.call,
    required this.isDark,
    required this.onTap,
    required this.onInfoTap,
  });

  String _formatCallTime(String? createdAtStr) {
    final createdAt = DateTime.tryParse(createdAtStr ?? '') ?? DateTime.now();
    final now = DateTime.now();
    final localTime = createdAt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(localTime.year, localTime.month, localTime.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (msgDay == today) {
      return DateFormat('HH:mm').format(localTime);
    } else if (msgDay == yesterday) {
      return 'Kemarin';
    } else if (now.difference(localTime).inDays < 7) {
      const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      return days[localTime.weekday - 1];
    } else {
      return DateFormat('dd/MM/yy').format(localTime);
    }
  }

  String _buildCallSubtitle(bool isGroup, bool isVideo, String durationText, bool isMissed, String? groupMembersText) {
    final parts = <String>[];

    if (isGroup) {
      parts.add(isVideo ? 'Video Grup' : 'Suara Grup');
      if (groupMembersText != null) parts.add(groupMembersText);
    } else {
      parts.add(isVideo ? 'Video' : 'Suara');
    }

    if (durationText.isNotEmpty) {
      parts.add(durationText);
    }

    if (isMissed) {
      parts.add('Tidak dijawab');
    }

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = call['is_group'] == true;
    final name = call['other_user_name']?.toString() ?? 'Unknown';
    final type = call['type']?.toString() ?? 'voice';
    final status = call['status']?.toString() ?? 'missed';
    final duration = int.tryParse(call['duration']?.toString() ?? '0') ?? 0;
    final isOutgoing = call['is_outgoing'] == true;
    final isMissed = status == 'missed';
    final isVideo = type == 'video';
    final timeStr = _formatCallTime(call['created_at']?.toString());

    // Format duration
    String durationText = '';
    if (status == 'answered' && duration > 0) {
      final m = duration ~/ 60;
      final s = duration % 60;
      durationText = m > 0 ? '${m}m ${s}s' : '${s}s';
    }

    // Group members subtitle
    String? groupMembersText;
    if (isGroup) {
      final memberCount = call['group_member_count'] ?? 0;
      if (memberCount > 0) {
        groupMembersText = '$memberCount anggota';
      }
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isDark ? RupiaColors.bgDark : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            if (isGroup)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? RupiaColors.primary.withOpacity(0.2) : RupiaColors.primary.withOpacity(0.1),
                ),
                child: Icon(Icons.groups_rounded, color: RupiaColors.primary, size: 24),
              )
            else
              AvatarWidget(
                name: name,
                size: 48,
                photoUrl: call['other_user_photo']?.toString(),
                interactive: false,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isMissed
                          ? const Color(0xFFEF4444)
                          : (isDark ? Colors.white : RupiaColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        isMissed
                            ? Icons.call_missed_rounded
                            : (isOutgoing ? Icons.call_made_rounded : Icons.call_received_rounded),
                        size: 14,
                        color: isMissed ? const Color(0xFFEF4444) : (isDark ? Colors.white38 : RupiaColors.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        size: 14,
                        color: isDark ? Colors.white38 : RupiaColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _buildCallSubtitle(isGroup, isVideo, durationText, isMissed, groupMembersText),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : RupiaColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Time
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : RupiaColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            // Info (i) icon
            GestureDetector(
              onTap: onInfoTap,
              child: Icon(
                Icons.info_outline_rounded,
                size: 22,
                color: isDark ? Colors.white30 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
