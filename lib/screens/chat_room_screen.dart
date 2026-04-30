import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../widgets/message_bubble.dart';
import '../widgets/payment_bubble.dart';
import '../widgets/avatar_widget.dart';
import '../utils/colors.dart';
import 'dart:async';
import 'call_screen.dart';
import 'contact_info_screen.dart';
import '../widgets/call_bubble.dart';

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

class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();

  List<MessageModel> _messages = [];
  bool _loading = true;

  StreamSubscription? _subscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _readSubscription;
  Timer? _typingTimer;
  Timer? _pollTimer;
  bool _isTyping = false;
  bool _isOtherUserTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChatService.initPusher();
    _loadHistory();
    _listenRealtime();
    _listenTypingState();
    _listenReadReceipts();
    _startPollingFallback();
    widget.chatService.markAsRead(widget.roomId);

    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isTyping) {
      widget.chatService.sendTyping(widget.roomId, false);
    }
    widget.chatService.leaveRoom(widget.roomId);
    _typingTimer?.cancel();
    _pollTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _subscription?.cancel();
    _typingSubscription?.cancel();
    _readSubscription?.cancel();
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Saat app kembali dari background, reconnect Pusher & refresh pesan
      ChatService.initPusher();
      _loadHistory();
    }
  }

  /// Polling fallback: setiap 5 detik, cek pesan baru dari server.
  /// Ini mengatasi kelemahan Android yang sering putus WebSocket.
  void _startPollingFallback() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _pollNewMessages();
    });
  }

  Future<void> _pollNewMessages() async {
    try {
      final freshMessages = await widget.chatService.loadMessages(widget.roomId);
      if (!mounted || freshMessages.isEmpty) return;
      final reversed = freshMessages.reversed.toList();
      bool changed = false;

      for (final msg in reversed) {
        if (msg.id.startsWith('temp_')) continue;

        final existingIndex = _messages.indexWhere((m) => m.id == msg.id);
        if (existingIndex != -1) {
          // Pesan sudah ada — cek apakah statusnya berubah (delivered → read)
          if (_messages[existingIndex].status != msg.status) {
            _messages[existingIndex] = msg;
            changed = true;
          }
        } else {
          // Cek apakah ada versi temp_ dari pesan ini (same text + sender)
          final tempIndex = _messages.indexWhere((m) =>
            m.id.startsWith('temp_') &&
            m.text == msg.text &&
            m.senderId == msg.senderId
          );
          if (tempIndex != -1) {
            // Ganti temp_ dengan pesan asli dari server
            _messages[tempIndex] = msg;
            changed = true;
          } else {
            // Pesan baru yang benar-benar belum ada
            _messages.insert(0, msg);
            changed = true;
          }
        }
      }

      if (changed && mounted) {
        setState(() {});
        widget.chatService.markAsRead(widget.roomId);
      }
    } catch (_) {}
  }

  void _onTextChanged() {
    if (_controller.text.trim().isNotEmpty) {
      if (!_isTyping) {
        setState(() => _isTyping = true);
        widget.chatService.sendTyping(widget.roomId, true);
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _isTyping) {
          setState(() => _isTyping = false);
          widget.chatService.sendTyping(widget.roomId, false);
        }
      });
    } else {
      if (_isTyping) {
        _typingTimer?.cancel();
        setState(() => _isTyping = false);
        widget.chatService.sendTyping(widget.roomId, false);
      }
    }
  }

  Future<void> _loadHistory() async {
    final messages = await widget.chatService.loadMessages(widget.roomId);
    if (!mounted) return;
    setState(() {
      _messages = messages.reversed.toList();
      _loading = false;
    });
  }

  void _listenTypingState() {
    _typingSubscription = widget.chatService.listenTyping(widget.roomId).listen((data) {
      if (data['user_id'] != widget.currentUid && mounted) {
        setState(() {
          _isOtherUserTyping = data['is_typing'];
        });
      }
    });
  }

  void _listenRealtime() {
    _subscription =
        widget.chatService.listenMessages(widget.roomId).listen((newMsg) {
      if (mounted) {
        setState(() {
          // Cari apakah ada pesan temp_ dari kita yang isinya sama
          final index = _messages.indexWhere((m) => 
            m.id.startsWith('temp_') && 
            m.text == newMsg.text && 
            m.senderId == newMsg.senderId
          );

          if (index != -1) {
            _messages[index] = newMsg;
          } else {
            if (!_messages.any((m) => m.id == newMsg.id)) {
              _messages.insert(0, newMsg);
            }
          }

          if (newMsg.senderId != widget.currentUid) {
            widget.chatService.markAsRead(widget.roomId);
          }
        });
      }
    });
  }

  void _listenReadReceipts() {
    _readSubscription = widget.chatService.listenReadReceipt(widget.roomId).listen((data) {
      if (data['user_id'] != widget.currentUid && mounted) {
        setState(() {
          // Update semua pesan kita menjadi 'read' (Centang 2 biru)
          for (int i = 0; i < _messages.length; i++) {
            if (_messages[i].senderId == widget.currentUid && _messages[i].status != 'read') {
              _messages[i] = MessageModel(
                id: _messages[i].id,
                senderId: _messages[i].senderId,
                text: _messages[i].text,
                type: _messages[i].type,
                timestamp: _messages[i].timestamp,
                status: 'read',
              );
            }
          }
        });
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
        await widget.chatService.sendImage(
          roomId: widget.roomId,
          senderId: widget.currentUid,
          filePath: image.path,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengirim gambar')),
          );
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isTyping = false);
    _typingTimer?.cancel();
    widget.chatService.sendTyping(widget.roomId, false);

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = MessageModel(
      id: tempId,
      senderId: widget.currentUid,
      text: text,
      type: 'text',
      timestamp: DateTime.now(),
      status: 'sending',
    );

    setState(() {
      _messages.insert(0, tempMsg);
      _controller.clear();
    });

    try {
      await widget.chatService.sendMessage(
        roomId: widget.roomId,
        senderId: widget.currentUid,
        text: text,
      );
      
      // Update status ke 'sent' (centang 1) setelah API sukses
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == tempId);
          if (idx != -1) {
            _messages[idx] = MessageModel(
              id: _messages[idx].id,
              senderId: _messages[idx].senderId,
              text: _messages[idx].text,
              type: _messages[idx].type,
              timestamp: _messages[idx].timestamp,
              status: 'sent', // Berubah jadi centang 1
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim pesan')),
        );
        setState(() {
          _messages.removeWhere((m) => m.id == tempId);
        });
      }
    }
  }
  void _startCall({required bool isVideo}) async {
    final callType = isVideo ? 'video' : 'voice';
    // Kirim pesan dengan format JSON agar bisa diparse jadi CallBubble
    await widget.chatService.sendMessage(
      roomId: widget.roomId,
      senderId: widget.currentUid,
      text: '{"call_type":"$callType","status":"missed","duration":0}',
      type: 'call',
    );
    if (mounted) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => CallScreen(
          channelName: widget.roomId,
          otherUserName: widget.otherUser.name,
          otherUserId: widget.otherUser.uid,
          otherUserPhoto: widget.otherUser.photoUrl,
          isVideoCall: isVideo,
        ),
      ));
    }
  }

  void _showPaymentSheet() {
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: RupiaColors.textHint,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Kirim ke ${widget.otherUser.name}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: RupiaColors.textPrimary)),
          const SizedBox(height: 20),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Jumlah (Rp)',
              prefixIcon: const Icon(Icons.monetization_on_outlined,
                  color: RupiaColors.gold),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RupiaColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Kirim Sekarang',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
        ]),
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
            leadingWidth: 30,
            leading: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ContactInfoScreen(
                    user: widget.otherUser,
                    roomId: widget.roomId,
                    currentUid: widget.currentUid,
                  ),
                ));
              },
              child: Row(children: [
                AvatarWidget(
                  name: widget.otherUser.name,
                  size: 36,
                  photoUrl: widget.otherUser.photoUrl,
                  interactive: true,
                  heroTag: 'avatar_appbar_${widget.otherUser.uid}',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.otherUser.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
                    Text(
                      _isOtherUserTyping
                          ? 'Sedang mengetik...'
                          : (widget.otherUser.isOnline ? 'Online' : 'Offline'),
                      maxLines: 1,
                      style: TextStyle(
                        color: _isOtherUserTyping
                            ? RupiaColors.gold
                            : (widget.otherUser.isOnline ? const Color(0xFF86EFAC) : Colors.white54),
                        fontSize: 12,
                        fontStyle: _isOtherUserTyping ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 24),
                onPressed: () => _startCall(isVideo: true),
              ),
              IconButton(
                icon: const Icon(Icons.call_rounded, color: Colors.white, size: 22),
                onPressed: () => _startCall(isVideo: false),
              ),
            ],
          ),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(
              child: CircularProgressIndicator(color: RupiaColors.primary))
              : _messages.isEmpty
              ? Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AvatarWidget(
                name: widget.otherUser.name, 
                size: 64,
                photoUrl: widget.otherUser.photoUrl,
                interactive: true,
                heroTag: 'avatar_empty_${widget.otherUser.uid}',
              ),
              const SizedBox(height: 12),
              Text(widget.otherUser.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: isDarkMode ? Colors.white : RupiaColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Belum ada pesan, mulai percakapan!',
                  style: TextStyle(color: isDarkMode ? Colors.white54 : RupiaColors.textSecondary)),
            ]),
          )
              : ListView.builder(
            controller: _scrollCtrl,
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final msg = _messages[i];
              final isMe = msg.senderId == widget.currentUid;
              final time = DateFormat('HH:mm').format(msg.timestamp.toLocal());

              // Date separator
              final msgDate = msg.timestamp.toLocal();
              final prevDate =
                  i < _messages.length - 1 ? _messages[i + 1].timestamp.toLocal() : null;
              final showDate = prevDate == null ||
                  msgDate.year != prevDate.year ||
                  msgDate.month != prevDate.month ||
                  msgDate.day != prevDate.day;

              Widget bubble;
              if (msg.type == 'payment') {
                bubble = PaymentBubble(
                  amount: msg.amount ?? '',
                  senderName: widget.otherUser.name,
                  isMe: isMe,
                  time: time,
                );
              } else if (msg.type == 'call' || msg.text.startsWith('📞') || msg.text.startsWith('📹')) {
                // Parse call data
                bool isVideo = false;
                String callStatus = 'missed';
                int callDuration = 0;
                
                if (msg.text.startsWith('{')) {
                  try {
                    final data = msg.text;
                    isVideo = data.contains('"video"');
                    if (data.contains('"answered"')) callStatus = 'answered';
                    final durMatch = RegExp(r'"duration":(\d+)').firstMatch(data);
                    if (durMatch != null) callDuration = int.tryParse(durMatch.group(1)!) ?? 0;
                  } catch (_) {}
                } else {
                  isVideo = msg.text.startsWith('📹');
                }
                
                bubble = CallBubble(
                  isMe: isMe,
                  isVideo: isVideo,
                  status: callStatus,
                  duration: callDuration,
                  time: time,
                );
              } else {
                bubble = MessageBubble(
                  text: msg.text,
                  isMe: isMe,
                  time: time,
                  isRead: msg.isRead,
                  type: msg.type,
                  id: msg.id,
                  status: msg.status,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showDate)
                    _ChatDateSeparator(
                      label: _chatDateLabel(msgDate),
                      isDarkMode: isDarkMode,
                    ),
                  bubble,
                ],
              );
            },
          ),
        ),
        Container(
          color: isDarkMode ? RupiaColors.cardDark : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(children: [
            // Attachment button (paperclip) — Photo & Kirim Rp
            PopupMenuButton<String>(
              icon: Icon(Icons.attach_file_rounded,
                  color: isDarkMode ? Colors.white70 : RupiaColors.textSecondary, size: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: isDarkMode ? RupiaColors.cardDark : Colors.white,
              elevation: 8,
              offset: const Offset(0, -120),
              onSelected: (value) {
                if (value == 'photo') _pickImage();
                if (value == 'payment') _showPaymentSheet();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'photo',
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: RupiaColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.image_rounded, color: RupiaColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Foto', style: TextStyle(
                        color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
                        fontWeight: FontWeight.w500)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'payment',
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: RupiaColors.gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.monetization_on_rounded, color: RupiaColors.gold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Kirim Rp', style: TextStyle(
                        color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
                        fontWeight: FontWeight.w500)),
                  ]),
                ),
              ],
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    color: isDarkMode ? RupiaColors.bgDark : RupiaColors.bg,
                    borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: isDarkMode ? Colors.white : RupiaColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Tulis pesan...',
                    hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : RupiaColors.textHint),
                    border: InputBorder.none,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                    color: RupiaColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Date label (private chat) ────────────────────────────────
String _chatDateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(date.year, date.month, date.day);

  if (d == today) return 'Hari ini';
  if (d == yesterday) return 'Kemarin';

  final pattern = d.year == now.year ? 'EEE, d MMM' : 'EEE, d MMM yyyy';
  return DateFormat(pattern, 'id').format(date);
}

// ── Date separator widget (private chat) ─────────────────────
class _ChatDateSeparator extends StatelessWidget {
  final String label;
  final bool isDarkMode;

  const _ChatDateSeparator({required this.label, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.12)
                : Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : const Color(0xFF555555),
            ),
          ),
        ),
      ),
    );
  }
}
