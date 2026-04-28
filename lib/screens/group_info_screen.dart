import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar_widget.dart';
import '../utils/colors.dart';
import 'group_call_screen.dart';
import 'group_chat_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String currentUid;
  final bool showCallHistory;

  const GroupInfoScreen({super.key, required this.groupId, required this.currentUid, this.showCallHistory = false});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  Map<String, dynamic>? _group;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _callLogs = [];
  String _myRole = 'member';
  bool _loading = true;
  bool _loadingCalls = true;

  bool get _isAdmin => _myRole == 'admin';

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
    if (widget.showCallHistory) _loadGroupCallLogs();
    else _loadingCalls = false;
  }

  Dio _authedDio(String token) {
    final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    dio.options.headers['Authorization'] = 'Bearer $token';
    dio.options.headers['Accept'] = 'application/json';
    return dio;
  }

  Future<void> _loadGroupInfo() async {
    try {
      final token = await AuthService().currentToken;
      if (token == null) return;
      final res = await _authedDio(token).get('/api/groups/${widget.groupId}');
      final data = res.data['data'];
      if (mounted) {
        setState(() {
          _group = Map<String, dynamic>.from(data);
          _myRole = data['my_role']?.toString() ?? 'member';
          _members = (data['members'] as List).map((m) => Map<String, dynamic>.from(m)).toList();
          // Sort: admin first, then by name
          _members.sort((a, b) {
            if (a['role'] == 'admin' && b['role'] != 'admin') return -1;
            if (a['role'] != 'admin' && b['role'] == 'admin') return 1;
            return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
          });
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('LoadGroupInfo Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadGroupCallLogs() async {
    try {
      final token = await AuthService().currentToken;
      if (token == null) { if (mounted) setState(() => _loadingCalls = false); return; }

      final res = await _authedDio(token).get('/api/call-logs/group/${widget.groupId}');
      final rawData = res.data;
      List<Map<String, dynamic>> calls = [];
      if (rawData is Map && rawData.containsKey('data')) {
        for (var item in (rawData['data'] as List)) {
          if (item is Map) calls.add(Map<String, dynamic>.from(item));
        }
      }
      if (mounted) setState(() { _callLogs = calls; _loadingCalls = false; });
    } catch (e) {
      debugPrint('LoadGroupCallLogs Error: $e');
      if (mounted) setState(() => _loadingCalls = false);
    }
  }

  void _startGroupCall({required bool isVideo}) {
    if (!mounted) return;
    final groupName = _group?['name'] ?? 'Grup';
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => GroupCallScreen(
        channelName: widget.groupId,
        groupName: groupName,
        isVideoCall: isVideo,
      ),
    ));
  }

  void _goToGroupChat() async {
    if (!mounted) return;
    final groupName = _group?['name'] ?? 'Grup';
    final groupPhoto = _group?['photo']?.toString();
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => GroupChatScreen(
        groupId: widget.groupId,
        groupName: groupName,
        groupPhoto: groupPhoto,
        currentUid: widget.currentUid,
      ),
    ));
  }

  List<Widget> _buildCallLogSections(bool isDark, Color textColor, Color subtextColor) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var call in _callLogs) {
      final createdAt = DateTime.tryParse(call['created_at']?.toString() ?? '') ?? DateTime.now();
      final localDate = createdAt.toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(localDate.year, localDate.month, localDate.day);
      String dateLabel;
      if (msgDay == today) { dateLabel = 'Hari Ini'; }
      else if (msgDay == today.subtract(const Duration(days: 1))) { dateLabel = 'Kemarin'; }
      else { dateLabel = DateFormat('dd MMM yyyy').format(localDate); }
      grouped.putIfAbsent(dateLabel, () => []);
      grouped[dateLabel]!.add(call);
    }

    List<Widget> widgets = [];
    grouped.forEach((dateLabel, calls) {
      widgets.add(Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: widgets.isEmpty ? 16 : 12, bottom: 8),
        child: Text(dateLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
      ));
      for (var call in calls) {
        final type = call['type']?.toString() ?? 'voice';
        final status = call['status']?.toString() ?? 'missed';
        final duration = int.tryParse(call['duration']?.toString() ?? '0') ?? 0;
        final isMissed = status == 'missed';
        final isVideo = type == 'video';
        final isOutgoing = call['is_outgoing'] == true;
        final callerName = call['caller_name']?.toString() ?? 'Unknown';
        final createdAt = DateTime.tryParse(call['created_at']?.toString() ?? '') ?? DateTime.now();
        final timeStr = DateFormat('HH:mm').format(createdAt.toLocal());
        String callDesc;
        if (isMissed) {
          callDesc = isVideo ? 'Panggilan video tidak dijawab' : 'Panggilan suara tidak dijawab';
        } else {
          callDesc = isVideo ? 'Panggilan video grup' : 'Panggilan suara grup';
        }
        String durationStr = '';
        if (status == 'answered' && duration > 0) {
          final m = duration ~/ 60; final s = duration % 60;
          durationStr = m > 0 ? '$m menit, $s detik' : '$s detik';
        }
        widgets.add(InkWell(
          onTap: () => _startGroupCall(isVideo: isVideo),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 44, child: Text(timeStr, style: TextStyle(fontSize: 13, color: subtextColor))),
              Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded, size: 16,
                  color: isMissed ? const Color(0xFFEF4444) : RupiaColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(callDesc, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: isMissed ? const Color(0xFFEF4444) : textColor)),
                Padding(padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      isOutgoing ? 'Oleh: Anda' : 'Oleh: $callerName',
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    )),
                if (durationStr.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2),
                      child: Text(durationStr, style: TextStyle(fontSize: 12, color: subtextColor))),
              ])),
              GestureDetector(
                onTap: () => _startGroupCall(isVideo: isVideo),
                child: Container(width: 32, height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: RupiaColors.primary.withOpacity(0.1)),
                  child: Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded, size: 16, color: RupiaColors.primary)),
              ),
            ]),
          ),
        ));
      }
    });
    widgets.add(const SizedBox(height: 12));
    return widgets;
  }

  void _showAddMemberSheet() async {
    final token = await AuthService().currentToken;
    if (token == null) return;
    final uid = await AuthService().currentUid ?? '';
    final chatService = ChatService();
    chatService.setToken(token);
    final allUsers = await chatService.getUsers(uid);
    
    // Filter out existing members
    final existingIds = _members.map((m) => m['id']?.toString()).toSet();
    final available = allUsers.where((u) => !existingIds.contains(u.uid)).toList();

    if (!mounted) return;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua kontak sudah menjadi anggota')));
      return;
    }

    final selected = <String>{};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            decoration: BoxDecoration(
              color: isDark ? RupiaColors.cardDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Expanded(child: Text('Tambah Anggota', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
                  if (selected.isNotEmpty)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: RupiaColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await _authedDio(token).post('/api/groups/${widget.groupId}/members',
                              data: {'member_ids': selected.toList()});
                          _loadGroupInfo();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${selected.length} anggota ditambahkan')));
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gagal menambah anggota')));
                        }
                      },
                      child: Text('Tambah (${selected.length})', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                ])),
              Expanded(child: ListView.builder(
                itemCount: available.length,
                itemBuilder: (_, i) {
                  final u = available[i];
                  final isSelected = selected.contains(u.uid);
                  return ListTile(
                    leading: AvatarWidget(name: u.name, size: 40, photoUrl: u.photoUrl, interactive: false),
                    title: Text(u.name),
                    subtitle: Text(u.phone ?? u.email, style: TextStyle(fontSize: 12,
                        color: isDark ? Colors.white38 : RupiaColors.textSecondary)),
                    trailing: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? RupiaColors.primary : Colors.grey),
                    onTap: () {
                      setSheetState(() {
                        if (isSelected) { selected.remove(u.uid); } else { selected.add(u.uid); }
                      });
                    },
                  );
                },
              )),
            ]),
          );
        });
      },
    );
  }

  Future<void> _removeMember(String userId, String name) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Keluarkan Anggota'),
      content: Text('Keluarkan $name dari grup?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluarkan', style: TextStyle(color: Color(0xFFEF4444)))),
      ],
    ));
    if (confirm != true) return;
    try {
      final token = await AuthService().currentToken;
      if (token == null) return;
      await _authedDio(token).delete('/api/groups/${widget.groupId}/members/$userId');
      _loadGroupInfo();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name telah dikeluarkan')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengeluarkan anggota')));
    }
  }

  Future<void> _makeAdmin(String userId, String name) async {
    try {
      final token = await AuthService().currentToken;
      if (token == null) return;
      await _authedDio(token).post('/api/groups/${widget.groupId}/members/$userId/make-admin');
      _loadGroupInfo();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name dijadikan admin')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menjadikan admin')));
    }
  }

  Future<void> _removeAdmin(String userId, String name) async {
    try {
      final token = await AuthService().currentToken;
      if (token == null) return;
      await _authedDio(token).post('/api/groups/${widget.groupId}/members/$userId/remove-admin');
      _loadGroupInfo();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name bukan admin lagi')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengubah role')));
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Keluar dari Grup'),
      content: const Text('Anda yakin ingin keluar dari grup ini?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(color: Color(0xFFEF4444)))),
      ],
    ));
    if (confirm != true) return;
    try {
      final token = await AuthService().currentToken;
      if (token == null) return;
      await _authedDio(token).post('/api/groups/${widget.groupId}/leave');
      if (mounted) {
        Navigator.pop(context, 'left');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal keluar dari grup')));
    }
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus Grup'),
      content: const Text('Grup akan dihapus secara permanen. Lanjutkan?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Color(0xFFEF4444)))),
      ],
    ));
    if (confirm != true) return;
    try {
      final token = await AuthService().currentToken;
      if (token == null) return;
      await _authedDio(token).delete('/api/groups/${widget.groupId}');
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus grup')));
    }
  }

  void _showMemberOptions(Map<String, dynamic> member) {
    final memberId = member['id']?.toString() ?? '';
    final memberName = member['name']?.toString() ?? '';
    final memberRole = member['role']?.toString() ?? 'member';
    final isMe = memberId == widget.currentUid;
    if (isMe || !_isAdmin) return;

    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Container(
        decoration: BoxDecoration(
          color: isDark ? RupiaColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(16),
            child: Text(memberName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
          if (memberRole != 'admin')
            ListTile(leading: const Icon(Icons.admin_panel_settings, color: RupiaColors.primary),
              title: const Text('Jadikan Admin'), onTap: () { Navigator.pop(ctx); _makeAdmin(memberId, memberName); }),
          if (memberRole == 'admin')
            ListTile(leading: const Icon(Icons.person_outline, color: Colors.orange),
              title: const Text('Hapus dari Admin'), onTap: () { Navigator.pop(ctx); _removeAdmin(memberId, memberName); }),
          ListTile(leading: const Icon(Icons.person_remove, color: Color(0xFFEF4444)),
            title: const Text('Keluarkan dari Grup', style: TextStyle(color: Color(0xFFEF4444))),
            onTap: () { Navigator.pop(ctx); _removeMember(memberId, memberName); }),
          const SizedBox(height: 16),
        ]),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? RupiaColors.bgDark : RupiaColors.bg;
    final cardColor = isDark ? RupiaColors.cardDark : Colors.white;
    final textColor = isDark ? Colors.white : RupiaColors.textPrimary;
    final subtextColor = isDark ? Colors.white54 : RupiaColors.textSecondary;

    if (_loading) {
      return Scaffold(backgroundColor: bgColor,
        appBar: AppBar(title: const Text('Info Grup')),
        body: const Center(child: CircularProgressIndicator(color: RupiaColors.primary)));
    }

    final groupName = _group?['name'] ?? 'Grup';
    final description = _group?['description']?.toString() ?? '';
    final photo = _group?['photo']?.toString();

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(slivers: [
        // Header
        SliverAppBar(expandedHeight: 0, pinned: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          title: const Text('Info Grup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          centerTitle: true,
          flexibleSpace: Container(decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF0D2B6B), RupiaColors.primary]))),
        ),

        // Avatar + Name
        SliverToBoxAdapter(child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [RupiaColors.primary, Color(0xFF2557B3)]),
            boxShadow: [BoxShadow(color: RupiaColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            Container(padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 3)),
              child: photo != null && photo.isNotEmpty
                  ? CircleAvatar(radius: 55, backgroundImage: NetworkImage(photo))
                  : CircleAvatar(radius: 55, backgroundColor: Colors.white.withOpacity(0.15),
                      child: const Icon(Icons.groups_rounded, size: 50, color: Colors.white70)),
            ),
            const SizedBox(height: 18),
            Text(groupName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 24)),
            const SizedBox(height: 6),
            Text('Grup · ${_members.length} anggota',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
          ]),
        )),

        // Quick Actions
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(children: [
            _actionBtn(Icons.chat_bubble_rounded, 'Pesan', _goToGroupChat, isDark),
            const SizedBox(width: 10),
            _actionBtn(Icons.call_rounded, 'Telepon', () => _startGroupCall(isVideo: false), isDark),
            const SizedBox(width: 10),
            _actionBtn(Icons.videocam_rounded, 'Video', () => _startGroupCall(isVideo: true), isDark),
            const SizedBox(width: 10),
            _actionBtn(Icons.search_rounded, 'Cari', _goToGroupChat, isDark),
          ]),
        )),

        // Description
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.info_outline_rounded, size: 18, color: subtextColor),
                const SizedBox(width: 8),
                Text('Deskripsi', style: TextStyle(fontSize: 12, color: subtextColor)),
              ]),
              const SizedBox(height: 8),
              Text(description.isEmpty ? 'Belum ada deskripsi' : description,
                  style: TextStyle(fontSize: 14, color: description.isEmpty ? subtextColor : textColor,
                      fontStyle: description.isEmpty ? FontStyle.italic : FontStyle.normal)),
            ]),
          ),
        )),

        // Call History (only from call history screen)
        if (widget.showCallHistory)
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: _loadingCalls
                  ? const Padding(padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: RupiaColors.primary, strokeWidth: 2)))
                  : _callLogs.isEmpty
                      ? Padding(padding: const EdgeInsets.all(20),
                          child: Row(children: [
                            Container(width: 36, height: 36,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: RupiaColors.primary.withOpacity(0.1)),
                              child: const Icon(Icons.call_rounded, color: RupiaColors.primary, size: 18)),
                            const SizedBox(width: 14),
                            Text('Belum ada riwayat panggilan', style: TextStyle(fontSize: 14, color: subtextColor)),
                          ]))
                      : Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildCallLogSections(isDark, textColor, subtextColor)),
            ),
          )),

        // Members Header + Add button
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(children: [
            Icon(Icons.people_alt_rounded, size: 20, color: subtextColor),
            const SizedBox(width: 8),
            Text('${_members.length} Anggota', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
            const Spacer(),
            if (_isAdmin)
              GestureDetector(
              onTap: () => _showAddMemberSheet(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: RupiaColors.primary, borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Tambah', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
        )),

        // Member List
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Container(
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Column(children: List.generate(_members.length, (i) {
              final m = _members[i];
              final isMe = m['id']?.toString() == widget.currentUid;
              final isAdminMember = m['role'] == 'admin';
              return Column(children: [
                if (i > 0) Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.black12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Stack(children: [
                    AvatarWidget(name: m['name'] ?? '', size: 44, photoUrl: m['photo_url']?.toString(), interactive: false),
                    if (m['is_online'] == true)
                      Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF22C55E),
                          border: Border.all(color: cardColor, width: 2)))),
                  ]),
                  title: Text('${m['name'] ?? ''}${isMe ? ' (Anda)' : ''}',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor)),
                  subtitle: Text(m['phone']?.toString() ?? m['email']?.toString() ?? '',
                      style: TextStyle(fontSize: 12, color: subtextColor)),
                  trailing: isAdminMember
                      ? Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: RupiaColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                          child: const Text('Admin', style: TextStyle(color: RupiaColors.primary, fontSize: 11, fontWeight: FontWeight.w600)))
                      : null,
                  onLongPress: () => _showMemberOptions(m),
                ),
              ]);
            })),
          ),
        )),

        // Media
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: RupiaColors.primary.withOpacity(0.1)),
                child: const Icon(Icons.photo_library_rounded, color: RupiaColors.primary, size: 18)),
              title: Text('Media, Link, dan Dokumen', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
              trailing: Icon(Icons.chevron_right, color: subtextColor, size: 22),
            ),
          ),
        )),

        // Danger Zone
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Container(
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Column(children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: const Icon(Icons.exit_to_app_rounded, color: Color(0xFFEF4444), size: 22),
                title: const Text('Keluar dari Grup', style: TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w500)),
                onTap: _leaveGroup),
              if (_isAdmin) ...[
                Divider(height: 1, indent: 56, color: isDark ? Colors.white10 : Colors.black12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 22),
                  title: const Text('Hapus Grup', style: TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w500)),
                  onTap: _deleteGroup),
              ],
            ]),
          ),
        )),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return Expanded(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: isDark ? RupiaColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
        child: Column(children: [
          Icon(icon, color: RupiaColors.primary, size: 24),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : RupiaColors.textPrimary)),
        ]),
      ),
    ));
  }
}
