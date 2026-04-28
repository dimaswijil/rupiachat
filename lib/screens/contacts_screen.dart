import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../widgets/avatar_widget.dart';
import '../utils/colors.dart';
import 'chat_room_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _auth = AuthService();
  final _chat = ChatService();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _loading = true;
  String _currentUid = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
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

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((u) =>
            u.name.toLowerCase().contains(query.toLowerCase())).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? RupiaColors.bgDark : RupiaColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Gradient Header ──
          SliverAppBar(
            expandedHeight: 100,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D2B6B), RupiaColors.primary],
                ),
              ),
              child: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
                title: Text('Kontak (${_allUsers.length})',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22)),
              ),
            ),
          ),

          // ── Search Bar ──
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? RupiaColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isDarkMode ? [] : [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterContacts,
                  style: TextStyle(color: isDarkMode ? Colors.white : RupiaColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Cari kontak...',
                    hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : RupiaColors.textHint),
                    prefixIcon: const Icon(Icons.search_rounded, color: RupiaColors.primary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // ── Contacts List ──
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: RupiaColors.primary)),
            )
          else if (_filteredUsers.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_search_rounded, size: 56,
                        color: isDarkMode ? Colors.white24 : RupiaColors.textHint),
                    const SizedBox(height: 12),
                    Text('Tidak ada kontak ditemukan',
                        style: TextStyle(
                            color: isDarkMode ? Colors.white54 : RupiaColors.textSecondary,
                            fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final user = _filteredUsers[index];
                  return _buildContactTile(user, isDarkMode);
                },
                childCount: _filteredUsers.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactTile(UserModel user, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: isDarkMode ? RupiaColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDarkMode ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Stack(
          children: [
            AvatarWidget(
              name: user.name,
              size: 46,
              photoUrl: user.photoUrl,
              interactive: true,
              heroTag: 'contact_${user.uid}',
            ),
            if (user.isOnline)
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 13, height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode ? RupiaColors.cardDark : Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(user.name,
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15,
                color: isDarkMode ? Colors.white : RupiaColors.textPrimary)),
        subtitle: Text(
          user.isOnline ? 'Online' : 'Offline',
          style: TextStyle(
            fontSize: 12,
            color: user.isOnline ? const Color(0xFF22C55E)
                : (isDarkMode ? Colors.white38 : RupiaColors.textSecondary),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionIcon(Icons.chat_bubble_rounded, () {
              final roomId = _chat.getRoomId(_currentUid, user.uid);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChatRoomScreen(
                  otherUser: user,
                  roomId: roomId,
                  currentUid: _currentUid,
                  chatService: _chat,
                ),
              ));
            }, isDarkMode),
          ],
        ),
        onTap: () {
          final roomId = _chat.getRoomId(_currentUid, user.uid);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              otherUser: user,
              roomId: roomId,
              currentUid: _currentUid,
              chatService: _chat,
            ),
          ));
        },
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap, bool isDarkMode) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: RupiaColors.primary.withOpacity(0.1),
        ),
        child: Icon(icon, size: 18, color: RupiaColors.primary),
      ),
    );
  }
}
