import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../widgets/avatar_widget.dart';
import '../utils/colors.dart';
import 'call_screen.dart';
import 'contact_info_screen.dart';

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
      );
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
          IconButton(icon: const Icon(Icons.call), onPressed: () => _startCall(isVideo: false)),
          IconButton(icon: const Icon(Icons.videocam), onPressed: () => _startCall(isVideo: true)),
          const SizedBox(width: 4),
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
                return _MessageBubble(message: msg, isMe: isMe);
              },
            ),
          ),
          _buildInputArea(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? RupiaColors.cardDark : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: RupiaColors.primary),
              onPressed: _pickImage,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? RupiaColors.bgDark : Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  onChanged: _onTyping,
                  style: TextStyle(color: isDark ? Colors.white : RupiaColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Ketik pesan...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: RupiaColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
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
                  _formatTime(message.createdAt),
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
