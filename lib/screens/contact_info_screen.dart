import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar_widget.dart';
import '../utils/colors.dart';
import 'chat_room_screen.dart';
import 'call_screen.dart';

class ContactInfoScreen extends StatefulWidget {
  final UserModel user;
  final String roomId;
  final String currentUid;
  final bool showCallHistory;

  const ContactInfoScreen({
    super.key,
    required this.user,
    required this.roomId,
    required this.currentUid,
    this.showCallHistory = false,
  });

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  List<Map<String, dynamic>> _callLogs = [];
  bool _loadingCalls = true;
  String? _actualCurrentUid;

  @override
  void initState() {
    super.initState();
    _initCurrentUid();
    if (widget.showCallHistory) {
      _loadUserCallLogs();
    } else {
      _loadingCalls = false;
    }
  }

  Future<void> _initCurrentUid() async {
    final uid = await AuthService().currentUid;
    if (mounted) {
      setState(() => _actualCurrentUid = uid);
    }
  }

  String get _currentUid => _actualCurrentUid ?? widget.currentUid;

  Future<void> _loadUserCallLogs() async {
    try {
      final token = await AuthService().currentToken;
      if (token == null) {
        if (mounted) setState(() => _loadingCalls = false);
        return;
      }
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      dio.options.headers['Authorization'] = 'Bearer $token';
      dio.options.headers['Accept'] = 'application/json';
      final res = await dio.get('/api/call-logs');
      final rawData = res.data;
      List<Map<String, dynamic>> allCalls = [];
      if (rawData is Map && rawData.containsKey('data')) {
        final dataList = rawData['data'];
        if (dataList is List) {
          for (var item in dataList) {
            if (item is Map) {
              allCalls.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
      // Filter hanya panggilan dengan user ini
      final userCalls = allCalls.where((c) =>
          c['other_user_id']?.toString() == widget.user.uid).toList();

      if (mounted) {
        setState(() {
          _callLogs = userCalls;
          _loadingCalls = false;
        });
      }
    } catch (e) {
      debugPrint('LoadUserCallLogs Error: $e');
      if (mounted) setState(() => _loadingCalls = false);
    }
  }

  /// Navigate to chat room
  void _goToChat() async {
    final chatService = ChatService();
    final token = await AuthService().currentToken;
    final uid = await AuthService().currentUid ?? '';
    if (token != null) chatService.setToken(token);
    final roomId = widget.roomId.isNotEmpty
        ? widget.roomId
        : chatService.getRoomId(uid, widget.user.uid);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          otherUser: widget.user,
          roomId: roomId,
          currentUid: uid,
          chatService: chatService,
        ),
      ));
    }
  }

  /// Start a voice call
  void _startCall() async {
    final uid = await AuthService().currentUid ?? '';
    final channelName = 'call_${uid}_${widget.user.uid}';
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CallScreen(
          channelName: channelName,
          otherUserName: widget.user.name,
          otherUserId: widget.user.uid,
          otherUserPhoto: widget.user.photoUrl,
          isVideoCall: false,
        ),
      ));
    }
  }

  /// Start a video call
  void _startVideoCall() async {
    final uid = await AuthService().currentUid ?? '';
    final channelName = 'call_${uid}_${widget.user.uid}';
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CallScreen(
          channelName: channelName,
          otherUserName: widget.user.name,
          otherUserId: widget.user.uid,
          otherUserPhoto: widget.user.photoUrl,
          isVideoCall: true,
        ),
      ));
    }
  }

  /// Search in chat — navigate to chat room with search mode
  void _searchInChat() async {
    final chatService = ChatService();
    final token = await AuthService().currentToken;
    final uid = await AuthService().currentUid ?? '';
    if (token != null) chatService.setToken(token);
    final roomId = widget.roomId.isNotEmpty
        ? widget.roomId
        : chatService.getRoomId(uid, widget.user.uid);
    if (mounted) {
      // Go to chat room (user can search from there)
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          otherUser: widget.user,
          roomId: roomId,
          currentUid: uid,
          chatService: chatService,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? RupiaColors.bgDark : RupiaColors.bg;
    final cardColor = isDarkMode ? RupiaColors.cardDark : Colors.white;
    final textColor = isDarkMode ? Colors.white : RupiaColors.textPrimary;
    final subtextColor = isDarkMode ? Colors.white54 : RupiaColors.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // ── Gradient Header ──
          SliverAppBar(
            expandedHeight: 0,
            floating: false,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Info Kontak',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            centerTitle: true,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D2B6B), RupiaColors.primary],
                ),
              ),
            ),
          ),

          // ── Avatar + Name Section ──
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [RupiaColors.primary, Color(0xFF2557B3)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: RupiaColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                    ),
                    child: AvatarWidget(
                      name: widget.user.name,
                      size: 110,
                      photoUrl: widget.user.photoUrl,
                      interactive: true,
                      heroTag: 'contact_info_${widget.user.uid}',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(widget.user.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 24)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.user.isOnline ? const Color(0xFF22C55E) : Colors.white38,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.user.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: widget.user.isOnline ? const Color(0xFF86EFAC) : Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Quick Actions ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  _buildActionButton(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Pesan',
                    color: RupiaColors.primary,
                    onTap: _goToChat,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(width: 10),
                  _buildActionButton(
                    icon: Icons.call_rounded,
                    label: 'Telepon',
                    color: RupiaColors.primary,
                    onTap: _startCall,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(width: 10),
                  _buildActionButton(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: RupiaColors.primary,
                    onTap: _startVideoCall,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(width: 10),
                  _buildActionButton(
                    icon: Icons.search_rounded,
                    label: 'Cari',
                    color: RupiaColors.primary,
                    onTap: _searchInChat,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ),
          ),

          // ── Riwayat Panggilan (HANYA jika dibuka dari call history) ──
          if (widget.showCallHistory)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDarkMode ? [] : [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: _loadingCalls
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator(color: RupiaColors.primary, strokeWidth: 2)),
                        )
                      : _callLogs.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: RupiaColors.primary.withOpacity(0.1),
                                    ),
                                    child: const Icon(Icons.call_rounded, color: RupiaColors.primary, size: 18),
                                  ),
                                  const SizedBox(width: 14),
                                  Text('Belum ada riwayat panggilan',
                                      style: TextStyle(fontSize: 14, color: subtextColor)),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildCallLogSections(isDarkMode, textColor, subtextColor),
                            ),
                ),
              ),
            ),

          // ── Info Card (Email + Telepon) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDarkMode ? [] : [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      value: widget.user.email,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      isDarkMode: isDarkMode,
                    ),
                    Divider(height: 1, indent: 56, color: isDarkMode ? Colors.white10 : Colors.black12),
                    _buildInfoRow(
                      icon: Icons.phone_rounded,
                      label: 'Telepon',
                      value: widget.user.phone ?? 'Tidak tersedia',
                      textColor: textColor,
                      subtextColor: subtextColor,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Media & Files ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDarkMode ? [] : [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: RupiaColors.primary.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: RupiaColors.primary, size: 18),
                  ),
                  title: Text('Media, Link, dan Dokumen',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                  trailing: Icon(Icons.chevron_right, color: subtextColor, size: 22),
                  onTap: () {},
                ),
              ),
            ),
          ),

          // ── Danger Zone ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDarkMode ? [] : [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: const Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 22),
                      title: Text('Blokir ${widget.user.name}',
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w500)),
                      onTap: () {},
                    ),
                    Divider(height: 1, indent: 56, color: isDarkMode ? Colors.white10 : Colors.black12),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 22),
                      title: const Text('Hapus Chat',
                          style: TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w500)),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── Build call log sections grouped by date ──
  List<Widget> _buildCallLogSections(bool isDark, Color textColor, Color subtextColor) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var call in _callLogs) {
      final createdAt = DateTime.tryParse(call['created_at']?.toString() ?? '') ?? DateTime.now();
      final localDate = createdAt.toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(localDate.year, localDate.month, localDate.day);
      final yesterday = today.subtract(const Duration(days: 1));

      String dateLabel;
      if (msgDay == today) {
        dateLabel = 'Hari Ini';
      } else if (msgDay == yesterday) {
        dateLabel = 'Kemarin';
      } else {
        dateLabel = DateFormat('dd MMM yyyy').format(localDate);
      }

      grouped.putIfAbsent(dateLabel, () => []);
      grouped[dateLabel]!.add(call);
    }

    List<Widget> widgets = [];
    grouped.forEach((dateLabel, calls) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16,
            top: widgets.isEmpty ? 16 : 12,
            bottom: 8,
          ),
          child: Text(dateLabel,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
        ),
      );

      for (var call in calls) {
        final type = call['type']?.toString() ?? 'voice';
        final status = call['status']?.toString() ?? 'missed';
        final duration = int.tryParse(call['duration']?.toString() ?? '0') ?? 0;
        final isOutgoing = call['is_outgoing'] == true;
        final isMissed = status == 'missed';
        final isVideo = type == 'video';
        final createdAt = DateTime.tryParse(call['created_at']?.toString() ?? '') ?? DateTime.now();
        final timeStr = DateFormat('HH:mm').format(createdAt.toLocal());

        String callDesc;
        if (isMissed) {
          callDesc = isVideo ? 'Panggilan video tidak dijawab' : 'Panggilan suara tidak dijawab';
        } else {
          callDesc = isOutgoing
              ? (isVideo ? 'Panggilan video keluar' : 'Panggilan suara keluar')
              : (isVideo ? 'Panggilan video masuk' : 'Panggilan suara masuk');
        }

        String durationStr = '';
        if (status == 'answered' && duration > 0) {
          final m = duration ~/ 60;
          final s = duration % 60;
          if (m > 0) {
            durationStr = '$m menit, $s detik';
          } else {
            durationStr = '$s detik';
          }
        }

        widgets.add(
          InkWell(
            onTap: () {
              // Tap on a call log entry → re-call
              _startCallFromLog(isVideo);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(timeStr,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : subtextColor)),
                  ),
                  Icon(
                    isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                    size: 16,
                    color: isMissed ? const Color(0xFFEF4444) : RupiaColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(callDesc,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                color: isMissed ? const Color(0xFFEF4444) : textColor)),
                        if (durationStr.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(durationStr,
                                style: TextStyle(fontSize: 12, color: subtextColor)),
                          ),
                      ],
                    ),
                  ),
                  // Call back button
                  GestureDetector(
                    onTap: () => _startCallFromLog(isVideo),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: RupiaColors.primary.withOpacity(0.1),
                      ),
                      child: Icon(
                        isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        size: 16,
                        color: RupiaColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    });

    widgets.add(const SizedBox(height: 12));
    return widgets;
  }

  void _startCallFromLog(bool isVideo) async {
    final uid = await AuthService().currentUid ?? '';
    final channelName = 'call_${uid}_${widget.user.uid}';
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CallScreen(
          channelName: channelName,
          otherUserName: widget.user.name,
          otherUserId: widget.user.uid,
          otherUserPhoto: widget.user.photoUrl,
          isVideoCall: isVideo,
        ),
      ));
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDarkMode ? RupiaColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isDarkMode ? [] : [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white70 : RupiaColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color subtextColor,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: RupiaColors.primary.withOpacity(0.1),
            ),
            child: Icon(icon, color: RupiaColors.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: subtextColor)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
