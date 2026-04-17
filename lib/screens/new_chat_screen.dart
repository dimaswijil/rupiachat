import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../widgets/avatar_widget.dart';
import '../utils/colors.dart';
import 'chat_room_screen.dart';
import 'create_group_screen.dart';

/// Screen "Chat Baru" — mirip WhatsApp New Chat
/// Menampilkan opsi "Grup Baru" + daftar semua kontak
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _auth = AuthService();
  final _chat = ChatService();
  final _searchCtrl = TextEditingController();

  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _loading = true;
  String _currentUid = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final uid = await _auth.currentUid ?? '';
    final token = await _auth.currentToken ?? '';
    _chat.setToken(token);

    final users = await _chat.getUsers(uid);

    if (mounted) {
      setState(() {
        _currentUid = uid;
        _allUsers = users;
        _filteredUsers = users;
        _loading = false;
      });
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers
            .where((u) =>
                u.name.toLowerCase().contains(query.toLowerCase()) ||
                (u.phone ?? '').contains(query))
            .toList();
      }
    });
  }

  void _openChat(UserModel user) {
    final roomId = _chat.getRoomId(_currentUid, user.uid);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          otherUser: user,
          roomId: roomId,
          currentUid: _currentUid,
          chatService: _chat,
        ),
      ),
    );
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
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Chat Baru',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          ),
        ),
      ),
      body: Column(
        children: [
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
                controller: _searchCtrl,
                onChanged: _filterUsers,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari nama atau nomor...',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white54 : RupiaColors.textHint,
                  ),
                  prefixIcon:
                      const Icon(Icons.search, color: RupiaColors.primary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: RupiaColors.primary))
                : ListView(
                    children: [
                      // ── Opsi Grup Baru ──────────────────────
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateGroupScreen(),
                            ),
                          );
                        },
                        child: Container(
                          color: isDarkMode ? RupiaColors.bgDark : Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: RupiaColors.primary,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(Icons.group_add,
                                    color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Grup baru',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : RupiaColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Divider ─────────────────────────────
                      Divider(
                        height: 1,
                        color: isDarkMode
                            ? Colors.white12
                            : Colors.grey.shade200,
                      ),

                      // ── Section label ───────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Kontak',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white38
                                : RupiaColors.textSecondary,
                          ),
                        ),
                      ),

                      // ── Daftar kontak ───────────────────────
                      if (_filteredUsers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person_search_outlined,
                                  size: 48,
                                  color: isDarkMode
                                      ? Colors.white24
                                      : RupiaColors.textHint,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchCtrl.text.isNotEmpty
                                      ? 'Tidak ditemukan'
                                      : 'Belum ada kontak',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white54
                                        : RupiaColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(_filteredUsers.length, (i) {
                          final user = _filteredUsers[i];
                          return InkWell(
                            onTap: () => _openChat(user),
                            child: Container(
                              color: isDarkMode
                                  ? RupiaColors.bgDark
                                  : Colors.white,
                              margin: const EdgeInsets.only(bottom: 1),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      AvatarWidget(
                                        name: user.name,
                                        photoUrl: user.photoUrl,
                                      ),
                                      if (user.isOnline)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF22C55E),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isDarkMode
                                                    ? RupiaColors.bgDark
                                                    : Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: isDarkMode
                                                ? Colors.white
                                                : RupiaColors.textPrimary,
                                          ),
                                        ),
                                        if (user.phone != null &&
                                            user.phone!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            user.phone!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDarkMode
                                                  ? Colors.white54
                                                  : RupiaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
