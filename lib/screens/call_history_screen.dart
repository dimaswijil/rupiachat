import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../widgets/avatar_widget.dart';
import '../utils/colors.dart';
import 'contact_info_screen.dart';
import 'group_info_screen.dart';
import 'call_screen.dart';
import 'group_call_screen.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _calls = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCallLogs();
  }

  Future<void> _loadCallLogs() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final token = await AuthService().currentToken;
      if (token == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      dio.options.headers['Authorization'] = 'Bearer $token';
      dio.options.headers['Accept'] = 'application/json';

      final res = await dio.get('/api/call-logs');

      final rawData = res.data;
      List<Map<String, dynamic>> calls = [];

      if (rawData is Map && rawData.containsKey('data')) {
        final dataList = rawData['data'];
        if (dataList is List) {
          for (var item in dataList) {
            if (item is Map) {
              calls.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _calls = calls;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('LoadCallLogs Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredCalls {
    if (_searchQuery.isEmpty) return _calls;
    return _calls.where((c) {
      final name = (c['other_user_name'] ?? '').toString().toLowerCase();
      final groupName = (c['group_name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          groupName.contains(_searchQuery.toLowerCase());
    }).toList();
  }

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
      // Nama hari
      const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      return days[localTime.weekday - 1];
    } else {
      return DateFormat('dd/MM/yy').format(localTime);
    }
  }

  /// Tap on a call tile → repeat the call (voice or video)
  void _onCallTileTap(Map<String, dynamic> call) async {
    final isGroup = call['is_group'] == true;
    final type = call['type']?.toString() ?? 'voice';
    final isVideo = type == 'video';

    if (isGroup) {
      final groupId = call['group_id']?.toString() ?? '';
      final groupName = call['group_name']?.toString() ?? 'Grup';
      if (groupId.isEmpty) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => GroupCallScreen(
          channelName: groupId,
          groupName: groupName,
          isVideoCall: isVideo,
        ),
      ));
    } else {
      final uid = await AuthService().currentUid ?? '';
      final otherUserId = call['other_user_id']?.toString() ?? '';
      final otherUserName = call['other_user_name']?.toString() ?? 'Unknown';
      if (otherUserId.isEmpty) return;
      final channelName = 'call_${uid}_$otherUserId';
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CallScreen(
          channelName: channelName,
          otherUserName: otherUserName,
          otherUserId: otherUserId,
          isVideoCall: isVideo,
        ),
      ));
    }
  }

  /// Tap on info icon → navigate to contact/group info
  void _onInfoTap(Map<String, dynamic> call) async {
    final isGroup = call['is_group'] == true;
    final currentUid = await AuthService().currentUid ?? '';

    if (isGroup) {
      final groupId = call['group_id']?.toString() ?? '';
      if (groupId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Info grup tidak tersedia')),
          );
        }
        return;
      }
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => GroupInfoScreen(
            groupId: groupId,
            currentUid: currentUid,
            showCallHistory: true,
          ),
        ));
      }
    } else {
      final otherUser = UserModel(
        uid: call['other_user_id']?.toString() ?? '',
        name: call['other_user_name']?.toString() ?? 'Unknown',
        email: call['other_user_email']?.toString() ?? '',
        phone: call['other_user_phone']?.toString(),
        photoUrl: call['other_user_photo']?.toString(),
      );
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ContactInfoScreen(
            user: otherUser,
            roomId: '',
            currentUid: currentUid,
            showCallHistory: true,
          ),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredCalls;

    return Scaffold(
      backgroundColor: isDark ? RupiaColors.bgDark : RupiaColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF0D2B6B), RupiaColors.primary],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Panggilan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
            elevation: 0,
            automaticallyImplyLeading: false,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [RupiaColors.primary, Color(0xFF2557B3)],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? RupiaColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: (q) => setState(() => _searchQuery = q),
                style: TextStyle(color: isDark ? Colors.white : RupiaColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari panggilan...',
                  hintStyle: TextStyle(color: isDark ? Colors.white54 : RupiaColors.textHint),
                  prefixIcon: const Icon(Icons.search, color: RupiaColors.primary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // ── Call List ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: RupiaColors.primary))
                : filtered.isEmpty
                    ? _buildEmptyState(isDark)
                    : RefreshIndicator(
                        onRefresh: _loadCallLogs,
                        color: RupiaColors.primary,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => Column(
                            children: [
                              _buildCallTile(filtered[index], isDark),
                              Divider(indent: 72, height: 1, thickness: 0.5,
                                  color: isDark ? Colors.white10 : Colors.black12),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : RupiaColors.primary.withOpacity(0.08),
            ),
            child: Icon(Icons.call_rounded, size: 36,
                color: isDark ? Colors.white24 : RupiaColors.textHint),
          ),
          const SizedBox(height: 16),
          Text('Belum ada riwayat panggilan',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : RupiaColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Panggilan suara dan video\nakan muncul di sini',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5,
                  color: isDark ? Colors.white38 : RupiaColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCallTile(Map<String, dynamic> call, bool isDark) {
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
      onTap: () => _onCallTileTap(call),
      child: Container(
        color: isDark ? RupiaColors.bgDark : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          // Avatar
          if (isGroup)
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? RupiaColors.primary.withOpacity(0.2) : RupiaColors.primary.withOpacity(0.1),
              ),
              child: const Icon(Icons.groups_rounded, color: RupiaColors.primary, size: 24),
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
                Text(name,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15,
                        color: isMissed
                            ? const Color(0xFFEF4444)
                            : (isDark ? Colors.white : RupiaColors.textPrimary))),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(
                    isMissed
                        ? Icons.call_missed_rounded
                        : (isOutgoing ? Icons.call_made_rounded : Icons.call_received_rounded),
                    size: 14,
                    color: isMissed ? const Color(0xFFEF4444)
                        : (isDark ? Colors.white38 : RupiaColors.textSecondary),
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
                      style: TextStyle(fontSize: 12,
                          color: isDark ? Colors.white38 : RupiaColors.textSecondary),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          // Time
          Text(timeStr, style: TextStyle(fontSize: 11,
              color: isDark ? Colors.white38 : RupiaColors.textSecondary)),
          const SizedBox(width: 10),
          // Info (i) icon
          GestureDetector(
            onTap: () => _onInfoTap(call),
            child: Icon(Icons.info_outline_rounded, size: 22,
                color: isDark ? Colors.white30 : Colors.grey.shade400),
          ),
        ]),
      ),
    );
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
}
