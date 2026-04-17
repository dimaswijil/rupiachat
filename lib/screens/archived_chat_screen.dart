import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../utils/colors.dart';
import 'chat_room_screen.dart';
import '../widgets/avatar_widget.dart';
import 'dart:async';

class ArchivedChatScreen extends StatefulWidget {
  final String currentUid;
  final ChatService chatService;

  const ArchivedChatScreen({
    super.key,
    required this.currentUid,
    required this.chatService,
  });

  @override
  State<ArchivedChatScreen> createState() => _ArchivedChatScreenState();
}

class _ArchivedChatScreenState extends State<ArchivedChatScreen> {
  List<UserModel> _archivedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadArchived();
  }

  Future<void> _loadArchived() async {
    final users = await widget.chatService.getUsers(widget.currentUid);
    if (mounted) {
      setState(() {
        _archivedUsers = users.where((u) => u.isArchived).toList();
        _loading = false;
      });
    }
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
            title: const Text('Chat Diarsipkan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: RupiaColors.primary))
          : _archivedUsers.isEmpty
              ? Center(
                  child: Text('Tidak ada chat diarsipkan',
                      style: TextStyle(color: isDarkMode ? Colors.white54 : RupiaColors.textSecondary)),
                )
              : ListView.builder(
                  itemCount: _archivedUsers.length,
                  itemBuilder: (context, i) {
                    final user = _archivedUsers[i];
                    final roomId = widget.chatService.getRoomId(widget.currentUid, user.uid);

                    return Column(
                      children: [
                        Dismissible(
                          key: Key('archived_$roomId'),
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
                            color: RupiaColors.gold,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.unarchive, color: Colors.white),
                                Text('Buka Arsip', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              _showDeleteOptions(context, user, roomId);
                              return false;
                            }
                            return true;
                          },
                          onDismissed: (direction) {
                            if (direction == DismissDirection.endToStart) {
                              widget.chatService.toggleArchive(roomId, false);
                              setState(() { _archivedUsers.removeAt(i); });
                            }
                          },
                          child: ListTile(
                            leading: AvatarWidget(name: user.name, photoUrl: user.photoUrl),
                            title: Text(user.name,
                                style: TextStyle(
                                    color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
                                    fontWeight: FontWeight.w600)),
                            subtitle: const Text('Chat diarsipkan', style: TextStyle(fontSize: 12)),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatRoomScreen(
                                  otherUser: user,
                                  roomId: roomId,
                                  currentUid: widget.currentUid,
                                  chatService: widget.chatService,
                                ),
                              ),
                            ),
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
                  },
                ),
    );
  }

  void _showDeleteOptions(BuildContext context, UserModel user, String roomId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? RupiaColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Hapus Chat', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteChat(context, roomId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('Batal'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteChat(BuildContext context, String roomId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Chat?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('Pesan akan dihapus dari riwayat chat Anda.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.chatService.deleteRoom(roomId, 'me');
              _loadArchived();
            },
            child: const Text('Hapus untuk Saya', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.chatService.deleteRoom(roomId, 'everyone');
              _loadArchived();
            },
            child: const Text('Hapus untuk Semua', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
