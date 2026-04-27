import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../models/group_model.dart';
import '../widgets/avatar_widget.dart';
import '../utils/colors.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final _auth = AuthService();
  final _groupService = GroupService();
  List<GroupModel> _allGroups = [];
  List<GroupModel> _filteredGroups = [];
  bool _loading = true;
  String _currentUid = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final uid = await _auth.currentUid ?? '';
    final token = await _auth.currentToken ?? '';
    _groupService.setToken(token);
    final groups = await _groupService.getGroups();
    groups.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      final tA = a.lastMessageTime ?? DateTime(2000);
      final tB = b.lastMessageTime ?? DateTime(2000);
      return tB.compareTo(tA);
    });
    if (mounted) {
      setState(() {
        _currentUid = uid;
        _allGroups = groups;
        _filteredGroups = groups;
        _loading = false;
      });
    }
  }

  void _filterGroups(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGroups = _allGroups;
      } else {
        _filteredGroups = _allGroups.where((g) =>
            g.name.toLowerCase().contains(query.toLowerCase())).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? RupiaColors.bgDark : RupiaColors.bg,
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
            title: const Text('Grup',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.group_add_rounded, color: Colors.white, size: 22),
                tooltip: 'Buat Grup Baru',
                onPressed: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
                  _loadGroups();
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar (sama persis dengan Chat List) ──
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
                color: isDarkMode ? RupiaColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterGroups,
                style: TextStyle(color: isDarkMode ? Colors.white : RupiaColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari grup...',
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : RupiaColors.textHint),
                  prefixIcon: const Icon(Icons.search, color: RupiaColors.primary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          // ── Content ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: RupiaColors.primary))
                : _filteredGroups.isEmpty
                    ? _buildEmptyState(isDarkMode)
                    : RefreshIndicator(
                        onRefresh: _loadGroups,
                        color: RupiaColors.primary,
                        child: ListView.builder(
                          itemCount: _filteredGroups.length,
                          itemBuilder: (context, index) {
                            final group = _filteredGroups[index];
                            return Column(
                              children: [
                                _buildGroupTile(group, isDarkMode),
                                Divider(indent: 72, height: 1, thickness: 0.5,
                                    color: isDarkMode ? Colors.white10 : Colors.black12),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.06)
                  : RupiaColors.primary.withOpacity(0.08),
            ),
            child: Icon(Icons.groups_rounded, size: 36,
                color: isDarkMode ? Colors.white24 : RupiaColors.textHint),
          ),
          const SizedBox(height: 16),
          Text('Belum ada grup',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white70 : RupiaColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Buat grup baru untuk mulai\nbercakap dengan banyak orang',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5,
                  color: isDarkMode ? Colors.white38 : RupiaColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildGroupTile(GroupModel group, bool isDarkMode) {
    final time = _formatTime(group.lastMessageTime);
    final subtitle = _formatLastMessage(group.lastMessage, group.memberCount);

    return InkWell(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: group.id,
            groupName: group.name,
            groupPhoto: group.photo,
            currentUid: _currentUid,
          ),
        ));
        _loadGroups();
      },
      child: Container(
        color: isDarkMode ? RupiaColors.bgDark : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          // Avatar grup
          group.photo != null && group.photo!.isNotEmpty
              ? CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(group.photo!),
                )
              : Container(
                  width: 48, height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF2557B3), Color(0xFF0D2060)],
                    ),
                  ),
                  child: const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(group.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15,
                                    color: isDarkMode ? Colors.white : RupiaColors.textPrimary)),
                          ),
                          if (group.isPinned) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.push_pin, size: 14,
                                color: isDarkMode ? Colors.white38 : RupiaColors.textSecondary),
                          ],
                        ],
                      ),
                    ),
                    if (time.isNotEmpty)
                      Text(time, style: TextStyle(fontSize: 11,
                          color: isDarkMode ? Colors.white38 : RupiaColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13,
                        color: isDarkMode ? Colors.white54 : RupiaColors.textSecondary)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    return "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
  }

  String _formatLastMessage(String? msg, int memberCount) {
    if (msg == null || msg.isEmpty) return '$memberCount anggota';
    if (msg.startsWith('http')) return '📷 Foto';
    if (msg == '[Gambar]') return '📷 Foto';
    // Format pesan call agar tidak tampil JSON mentah
    if (msg.startsWith('{') && msg.contains('call_type')) {
      if (msg.contains('"video"')) return '📹 Panggilan Video';
      return '📞 Panggilan Suara';
    }
    return msg;
  }
}
