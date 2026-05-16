import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../utils/colors.dart';
import '../call/call_screen.dart';
import '../contacts/contact_info_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final UserModel otherUser;
  final String roomId;
  final String currentUid;
  final ChatService chatService;

  const ChatRoomScreen({
    super.key,
    required this.otherUser,
    required this.roomId,
    required this.currentUid,
    required this.chatService,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _isTyping = false;
  bool _otherUserTyping = false;
  Timer? _typingTimer;
  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _readSub;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupListeners();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _msgSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _typingTimer?.cancel();
    widget.chatService.sendTyping(widget.roomId, false);
    super.dispose();
  }

  void _setupListeners() {
    _msgSub = widget.chatService.listenMessages(widget.roomId).listen((msg) {
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == msg.id)) {
            _messages.insert(0, msg);
            if (msg.senderId != widget.currentUid) {
              widget.chatService.markAsRead(widget.roomId);
            }
          }
        });
      }
    });

    _typingSub = widget.chatService.listenTyping(widget.roomId).listen((data) {
      if (data['user_id'].toString() == widget.otherUser.uid.toString()) {
        if (mounted) setState(() => _otherUserTyping = data['is_typing']);
      }
    });

    _readSub = widget.chatService.listenReadReceipt(widget.roomId).listen((data) {
      if (data['user_id'].toString() == widget.otherUser.uid.toString()) {
        if (mounted) {
          setState(() {
            for (var i = 0; i < _messages.length; i++) {
              if (_messages[i].senderId == widget.currentUid) {
                _messages[i] = _messages[i].copyWith(isRead: true);
              }
            }
          });
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    final msgs = await widget.chatService.loadMessages(widget.roomId);
    if (mounted) setState(() => _messages = msgs.reversed.toList());
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    widget.chatService.sendTyping(widget.roomId, false);
    widget.chatService.sendMessage(
      roomId: widget.roomId,
      senderId: widget.currentUid,
      text: text,
    ).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    });
  }

  void _onTyping(String value) {
    if (!_isTyping && value.isNotEmpty) {
      _isTyping = true;
      widget.chatService.sendTyping(widget.roomId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _isTyping = false;
        widget.chatService.sendTyping(widget.roomId, false);
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (picked != null) {
      widget.chatService.sendImage(
        roomId: widget.roomId,
        senderId: widget.currentUid,
        filePath: picked.path,
      ).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      });
    }
  }

  Future<void> _pickCameraImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (picked != null) {
      widget.chatService.sendImage(
        roomId: widget.roomId,
        senderId: widget.currentUid,
        filePath: picked.path,
      ).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      });
    }
  }

  void _startCall({required bool isVideo}) {
    final channelName = 'call_${widget.currentUid}_${widget.otherUser.uid}';
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CallScreen(
        channelName: channelName,
        otherUserName: widget.otherUser.name,
        otherUserId: widget.otherUser.uid,
        otherUserPhoto: widget.otherUser.photoUrl,
        isVideoCall: isVideo,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? RupiaColors.bgDark : RupiaColors.bg,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: RupiaColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ContactInfoScreen(
              user: widget.otherUser,
              roomId: widget.roomId,
              currentUid: widget.currentUid,
            ),
          )),
          child: Row(
            children: [
              AvatarWidget(
                name: widget.otherUser.name,
                size: 36,
                photoUrl: widget.otherUser.photoUrl,
                heroTag: 'chat_room_${widget.otherUser.uid}',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.otherUser.name,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      _otherUserTyping ? 'Sedang mengetik...' : (widget.otherUser.isOnline ? 'Online' : 'Offline'),
                      style: TextStyle(
                        color: _otherUserTyping ? RupiaColors.gold : Colors.white70,
                        fontSize: 11,
                        fontWeight: _otherUserTyping ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined, size: 26), 
            onPressed: () => _startCall(isVideo: true)
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined, size: 24), 
            onPressed: () => _startCall(isVideo: false)
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 26), 
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Fitur opsi masih dalam pengembangan'), duration: Duration(seconds: 1))
               );
            }
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg.senderId == widget.currentUid;
                
                // Cek apakah perlu menampilkan header tanggal (pesan paling atas di harinya)
                bool showDate = false;
                if (index == _messages.length - 1) {
                  showDate = true; // Pesan terlama di list (paling atas di layar)
                } else {
                  final nextMsg = _messages[index + 1];
                  if (!_isSameDay(msg.timestamp, nextMsg.timestamp)) {
                    showDate = true;
                  }
                }
                
                Widget bubble = _MessageBubble(message: msg, isMe: isMe);
                
                if (showDate) {
                  return Column(
                    children: [
                      _buildDateHeader(msg.timestamp),
                      bubble,
                    ],
                  );
                }
                return bubble;
              },
            ),
          ),
          _buildInputArea(isDarkMode),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    final d1 = date1.toLocal();
    final d2 = date2.toLocal();
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final localTime = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(localTime.year, localTime.month, localTime.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    String dateStr;
    if (msgDay == today) {
      dateStr = 'Hari ini';
    } else if (msgDay == yesterday) {
      dateStr = 'Kemarin';
    } else if (now.difference(localTime).inDays < 7) {
      const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      dateStr = days[localTime.weekday - 1];
    } else {
      dateStr = "${localTime.day}/${localTime.month}/${localTime.year}";
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          dateStr,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF555555), 
            fontSize: 12, 
            fontWeight: FontWeight.w600
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.transparent,
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2B2B2B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey[500]),
                      onPressed: () {},
                    ),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: TextField(
                          controller: _messageController,
                          onChanged: _onTyping,
                          style: TextStyle(color: isDark ? Colors.white : RupiaColors.textPrimary),
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Ketik pesan',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.attach_file, color: Colors.grey[500]),
                      onPressed: () => _showAttachmentMenu(context, isDark),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _messageController,
                      builder: (context, value, child) {
                        if (value.text.isEmpty) {
                          return IconButton(
                            icon: Icon(Icons.camera_alt, color: Colors.grey[500]),
                            onPressed: _pickCameraImage,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) {
                final isTyping = value.text.isNotEmpty;
                return GestureDetector(
                  onTap: isTyping ? _sendMessage : null, // Voice note feature can be implemented later
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: RupiaColors.primary, // RupiaChat Blue
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isTyping ? Icons.send : Icons.mic, 
                      color: Colors.white, 
                      size: 22,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161F24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 20,
          children: [
            _buildAttachmentItem(ctx, icon: Icons.image, color: Colors.blueAccent, label: 'Galeri', isDev: false, onTap: () {
               Navigator.pop(ctx);
               Future.delayed(const Duration(milliseconds: 200), _pickImage);
            }),
            _buildAttachmentItem(ctx, icon: Icons.camera_alt, color: Colors.pinkAccent, label: 'Kamera', isDev: false, onTap: () {
               Navigator.pop(ctx);
               Future.delayed(const Duration(milliseconds: 200), _pickCameraImage);
            }),
            _buildAttachmentItem(ctx, icon: Icons.location_on, color: Colors.green, label: 'Lokasi', isDev: true),
            _buildAttachmentItem(ctx, icon: Icons.person, color: Colors.lightBlue, label: 'Kontak', isDev: true),
            _buildAttachmentItem(ctx, icon: Icons.insert_drive_file, color: Colors.deepPurpleAccent, label: 'Dokumen', isDev: true),
            _buildAttachmentItem(ctx, icon: Icons.headphones, color: Colors.orange, label: 'Audio', isDev: true),
            _buildAttachmentItem(ctx, icon: Icons.bar_chart, color: Colors.amber, label: 'Polling', isDev: true),
            _buildAttachmentItem(ctx, icon: Icons.event, color: Colors.redAccent, label: 'Acara', isDev: true),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(BuildContext context, {required IconData icon, required Color color, required String label, required bool isDev, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        if (isDev) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label masih dalam pengembangan'), duration: const Duration(seconds: 1)));
        } else {
           if (onTap != null) onTap();
        }
      },
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252A30) : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12), textAlign: TextAlign.center),
            if (isDev)
              Text('Dev', style: const TextStyle(color: RupiaColors.primary, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Check if message is a call log JSON
    String displayContent = message.text;
    bool isCallLog = false;
    if (displayContent.startsWith('{') && displayContent.contains('call_type')) {
      isCallLog = true;
      if (displayContent.contains('"video"')) {
        displayContent = '📹 Panggilan Video';
      } else {
        displayContent = '📞 Panggilan Suara';
      }
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? RupiaColors.primary : (isDark ? RupiaColors.cardDark : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.type == 'image')
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(message.text),
              )
            else
              Text(
                displayContent,
                style: TextStyle(
                  color: isMe ? Colors.white : (isDark ? Colors.white : RupiaColors.textPrimary),
                  fontStyle: isCallLog ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : (isDark ? Colors.white38 : RupiaColors.textSecondary),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead ? RupiaColors.gold : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
  }
}
