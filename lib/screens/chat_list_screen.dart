import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/group_service.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../widgets/avatar_widget.dart';
import '../utils/colors.dart';
import 'chat_room_screen.dart';
import 'archived_chat_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _auth = AuthService();
  final _chat = ChatService();
  final _groupService = GroupService();

  List<UserModel> _users = [];
  List<GroupModel> _groups = [];
  List<dynamic> _mergedChats = [];
  bool _loading = true;
  bool _isNavigating = false;
  String _currentUid = '';
  final _searchController = TextEditingController();

  Timer? _refreshDebounce;
  StreamSubscription? _globalSubscription;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshDebounce?.cancel();
    _globalSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final uid = await _auth.currentUid ?? '';
    final token = await _auth.currentToken ?? '';
    _chat.setToken(token);
    _groupService.setToken(token);

    // Await initPusher — aman karena Completer mencegah init ganda
    // dan panggilan kedua langsung return tanpa blocking.
    await ChatService.initPusher();

    final users = await _chat.getUsers(uid);
    final groups = await _groupService.getGroups();
    // Urutkan grup: yang dipin di atas
    groups.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });

    if (mounted) {
      setState(() {
        _currentUid = uid;
        _users = users;
        _groups = groups;
        _filterUsers(_searchController.text);
        _loading = false;
      });
      
      // Global Pusher Listener
      _globalSubscription?.cancel();
      _globalSubscription = _chat.listenGlobalNotifications(_currentUid).listen((_) {
        _onNewMessageReceived();
      });
    }
  }

  void _onNewMessageReceived() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(seconds: 1), () {
      _loadUsers();
    });
  }

  void _filterUsers(String query) {
    setState(() {
      final filteredUsers = _users.where((user) =>
          user.name.toLowerCase().contains(query.toLowerCase()) &&
          !user.isArchived).toList();

      _mergedChats = [...filteredUsers];
      
      // URUTKAN WHATSAPP STYLE (PIN -> TERBARU)
      _mergedChats.sort((a, b) {
        bool pinA = false;
        bool pinB = false;
        DateTime? timeA;
        DateTime? timeB;

        if (a is UserModel) {
          pinA = a.isPinned;
          timeA = a.lastMessageTime;
        } else if (a is GroupModel) {
          pinA = a.isPinned;
          timeA = a.lastMessageTime;
        }

        if (b is UserModel) {
          pinB = b.isPinned;
          timeB = b.lastMessageTime;
        } else if (b is GroupModel) {
          pinB = b.isPinned;
          timeB = b.lastMessageTime;
        }

        // 1. PIN Priority
        if (pinA && !pinB) return -1;
        if (!pinA && pinB) return 1;

        // 2. Time Priority
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        
        return timeB.compareTo(timeA); // Descending
      });
    });
  }

  void _showChatOptions(BuildContext context, UserModel user, String roomId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? RupiaColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      AvatarWidget(
                        name: user.name, 
                        size: 40,
                        photoUrl: user.photoUrl,
                        interactive: true,
                        heroTag: 'list_modal_${user.uid}',
                      ),
                      const SizedBox(width: 12),
                      Text(
                        user.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    user.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: RupiaColors.primary,
                  ),
                  title: Text(
                    user.isPinned ? 'Lepas pin' : 'Pin chat',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _togglePin(user, roomId);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.archive_outlined,
                    color: RupiaColors.primary,
                  ),
                  title: Text(
                    'Arsipkan chat',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _archiveChat(user, roomId);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Hapus Chat',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteChat(context, roomId, false);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteOptions(BuildContext context, dynamic item, String roomId, bool isGroup) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? RupiaColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              if (!isGroup) ...[
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Hapus Chat', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteChat(context, roomId, false);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text('Keluar Grup', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmExitGroup(context, (item as GroupModel).id);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Batal'),
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteChat(BuildContext context, String roomId, bool isGroup) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Chat?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('Pesan akan dihapus dari riwayat chat Anda.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _chat.deleteRoom(roomId, 'me');
              _loadUsers();
            },
            child: const Text('Hapus untuk Saya', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _chat.deleteRoom(roomId, 'everyone');
              _loadUsers();
            },
            child: const Text('Hapus untuk Semua', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmExitGroup(BuildContext context, String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Grup?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('Anda tidak akan bisa menerima pesan lagi di grup ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _groupService.leaveGroup(groupId);
              _loadUsers();
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _togglePin(UserModel user, String roomId) async {
    final newPinned = !user.isPinned;
    await _chat.togglePin(roomId, newPinned);
    await _loadUsers();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newPinned ? 'Chat di-pin' : 'Pin dilepas'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _archiveChat(UserModel user, String roomId) {
    setState(() {
      final index = _users.indexWhere((u) => u.uid == user.uid);
      if (index != -1) {
        _users[index] = user.copyWith(isArchived: true);
      }
      _filterUsers(_searchController.text);
    });

    _chat.toggleArchive(roomId, true).catchError((e) {
      debugPrint('Error archive chat: $e');
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
            title: const Text('RupiaChat',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_square, color: Colors.white, size: 22),
                tooltip: 'Buat Grup Baru',
                onPressed: () async {
                  if (_isNavigating) return;
                  _isNavigating = true;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewChatScreen()),
                  );
                  _isNavigating = false;
                  _loadUsers();
                },
              ),
            ],
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
                controller: _searchController,
                onChanged: _filterUsers,
                style: TextStyle(color: isDarkMode ? Colors.white : RupiaColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari kontak...',
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : RupiaColors.textHint),
                  prefixIcon: const Icon(Icons.search, color: RupiaColors.primary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                child: CircularProgressIndicator(color: RupiaColors.primary))
                : RefreshIndicator(
              onRefresh: _loadUsers,
              color: RupiaColors.primary,
              child: ListView(
                children: [
                  if (_users.any((u) => u.isArchived))
                    ListTile(
                      onTap: () async {
                        if (_isNavigating) return;
                        _isNavigating = true;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArchivedChatScreen(
                              currentUid: _currentUid,
                              chatService: _chat,
                            ),
                          ),
                        );
                        _isNavigating = false;
                        _loadUsers();
                      },
                      leading: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.archive_outlined, color: RupiaColors.primary),
                      ),
                      title: const Text('Diarsipkan',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Text(
                        _users.where((u) => u.isArchived).length.toString(),
                        style: const TextStyle(color: RupiaColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  // ── Chat Pribadi ──────────────────────────────
                  ...List.generate(_mergedChats.length, (i) {
                    final item = _mergedChats[i];
                    final user = item as UserModel;
                    final roomId = _chat.getRoomId(_currentUid, user.uid);

                    return Column(
                      children: [
                        Dismissible(
                          key: Key('chat_$roomId'),
                          direction: DismissDirection.horizontal,
                          background: Container(
                            color: Colors.grey.shade700,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.more_horiz, color: Colors.white),
                                Text('Lainnya', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                          secondaryBackground: Container(
                            color: RupiaColors.primary,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.archive, color: Colors.white),
                                Text('Arsip', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              _showChatOptions(context, user, roomId);
                              return false;
                            }
                            return true;
                          },
                          onDismissed: (direction) {
                            if (direction == DismissDirection.endToStart) {
                              _archiveChat(user, roomId);
                            }
                          },
                          child: _UserTile(
                            key: ValueKey(roomId),
                            user: user,
                            roomId: roomId,
                            currentUid: _currentUid,
                            chat: _chat,
                            onTap: () async {
                              if (_isNavigating) return;
                              _isNavigating = true;
                              await _chat.markAsRead(roomId);
                              await Navigator.push(
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
                              _isNavigating = false;
                              _loadUsers();
                            },
                            onLongPress: () => _showChatOptions(context, user, roomId),
                            onNewMessage: _onNewMessageReceived,
                          ),
                        ),
                        Divider(
                          indent: 72, 
                          height: 1, 
                          thickness: 0.5, 
                          color: isDarkMode ? Colors.white10 : Colors.black12,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatefulWidget {
  final UserModel user;
  final String roomId;
  final String currentUid;
  final ChatService chat;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onNewMessage;

  const _UserTile({
    super.key,
    required this.user,
    required this.roomId,
    required this.currentUid,
    required this.chat,
    required this.onTap,
    required this.onLongPress,
    required this.onNewMessage,
  });

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  String _formatTimeFromDate(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    return "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    String rawMsg = widget.user.lastMessage ?? 'Mulai percakapan...';
    // Format pesan call agar tidak tampil JSON mentah
    if (rawMsg.startsWith('{') && rawMsg.contains('call_type')) {
      if (rawMsg.contains('"video"')) {
        rawMsg = '📹 Panggilan Video';
      } else {
        rawMsg = '📞 Panggilan Suara';
      }
    }
    final _lastMessage = rawMsg;
    final _unreadCount = widget.user.unreadCount ?? 0;
    final _time = _formatTimeFromDate(widget.user.lastMessageTime);

    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        color: isDarkMode ? RupiaColors.bgDark : Colors.white,
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Stack(children: [
            AvatarWidget(
              name: widget.user.name,
              photoUrl: widget.user.photoUrl,
              interactive: true,
              heroTag: 'list_row_${widget.user.uid}',
            ),
            if (widget.user.isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDarkMode ? RupiaColors.bgDark : Colors.white, width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(widget.user.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: isDarkMode ? Colors.white : RupiaColors.textPrimary)),
                          ),
                          if (widget.user.isPinned) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.push_pin,
                              size: 14,
                              color: isDarkMode ? Colors.white38 : RupiaColors.textSecondary,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_time.isNotEmpty)
                      Text(_time,
                          style: TextStyle(
                              fontSize: 11,
                              color: _unreadCount > 0
                                  ? RupiaColors.primary
                                  : (isDarkMode ? Colors.white38 : RupiaColors.textSecondary))),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(_lastMessage,
                          style: TextStyle(
                              fontSize: 13, color: isDarkMode ? Colors.white54 : RupiaColors.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (_unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: RupiaColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _unreadCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Widget Group Tile ─────────────────────────────────────────
class _GroupTile extends StatelessWidget {
  final GroupModel group;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _GroupTile({
    required this.group,
    required this.isDarkMode,
    required this.onTap,
  });

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    return "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
  }

  String _formatLastMessage(String? msg, int memberCount) {
    if (msg == null || msg.isEmpty) return '$memberCount anggota';
    if (msg.startsWith('http')) return '📷 Foto';
    if (msg == '[Gambar]') return '📷 Foto';
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isDarkMode ? RupiaColors.bgDark : Colors.white,
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          // Group avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: RupiaColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
              image: group.photo != null
                  ? DecorationImage(
                      image: NetworkImage(group.photo!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: group.photo == null
                ? const Icon(Icons.group, color: RupiaColors.primary, size: 24)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (group.lastMessageTime != null)
                          Text(
                            _formatTime(group.lastMessageTime),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode ? Colors.white38 : RupiaColors.textSecondary,
                            ),
                          ),
                        if (group.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Icon(Icons.push_pin, size: 14, color: RupiaColors.primary),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatLastMessage(group.lastMessage, group.memberCount),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white54 : RupiaColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}