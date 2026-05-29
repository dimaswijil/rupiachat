import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_storage_service.dart'; // Tambahkan ini
import '../../widgets/avatar_widget.dart';
import '../../widgets/image_viewer_dialog.dart';
import '../../utils/colors.dart';
import 'photo_confirm_screen.dart';
import '../call/call_screen.dart';
import '../contacts/contact_info_screen.dart';
import '../../services/purchase_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

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

class _ChatRoomScreenState extends State<ChatRoomScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<MessageModel> _messages = [];
  bool _isTyping = false;
  bool _otherUserTyping = false;
  Timer? _typingTimer;
  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _readSub;

  // ── RECORDING STATE VARIABLES ──
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  String? _recordingPath;

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        _recordingDuration = 0;
        _recordingPath = path;
        setState(() {
          _isRecording = true;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingDuration++;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null && _recordingPath != null) {
        await widget.chatService.sendAudio(
          roomId: widget.roomId,
          senderId: widget.currentUid,
          filePath: _recordingPath!,
        );
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  String get _recordingDurationString {
    final minutes = (_recordingDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

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
    _focusNode.dispose();
    _typingTimer?.cancel();
    _msgSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
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

  Future<void> _handlePhotoSend(String filePath) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoConfirmScreen(
          imagePath: filePath,
          title: widget.otherUser.name,
        ),
      ),
    );

    if (result != null && result['confirmed'] == true) {
      final String? caption = result['caption'];
      widget.chatService.sendImage(
        roomId: widget.roomId,
        senderId: widget.currentUid,
        filePath: filePath,
        caption: caption,
      ).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (picked != null) {
      _handlePhotoSend(picked.path);
    }
  }

  Future<void> _pickCameraImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (picked != null) {
      _handlePhotoSend(picked.path);
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        
        // 1. Unggah file PDF langsung ke Supabase Storage
        final publicUrl = await SupabaseStorageService().uploadFile(
          filePath: path,
          bucketName: 'messages_documents',
        );

        // 2. Kirim URL publik tersebut ke Laravel API
        await widget.chatService.sendMessage(
          roomId: widget.roomId,
          senderId: widget.currentUid,
          text: publicUrl,
          type: 'pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim PDF: $e')),
        );
      }
    }
  }

  void _startCall({required bool isVideo}) async {
    if (!PurchaseService().isFeatureUnlocked('voice_call')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fitur terkunci. Dapatkan VIP Member untuk melakukan panggilan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final channelName = 'call_${widget.currentUid}_${widget.otherUser.uid}';
    final callType = isVideo ? 'video' : 'voice';
    
    try {
      await widget.chatService.sendMessage(
        roomId: widget.roomId,
        senderId: widget.currentUid,
        text: '{"call_type":"$callType","status":"missed","duration":0}',
        type: 'call',
      );
    } catch (_) {}

    if (mounted) {
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 26, color: Colors.white),
            onSelected: (val) {
              if (val == 'info') {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ContactInfoScreen(
                    user: widget.otherUser,
                    roomId: widget.roomId,
                    currentUid: widget.currentUid,
                  ),
                ));
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'info',
                child: Text('Info Kontak'),
              ),
            ],
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
                
                Widget bubble = _MessageBubble(
                  message: msg,
                  isMe: isMe,
                  senderName: isMe ? 'Anda' : widget.otherUser.name,
                );
                
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
            // Left outside: "+" button for attachments
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: () => _showAttachmentMenu(context, isDark),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(bottom: 10, right: 8, left: 4),
            ),
            // Middle: Pill Container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2225) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.12) : Colors.grey.withOpacity(0.2),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: _isRecording
                    ? Row(
                        children: [
                          const _FlashingRedDot(),
                          const SizedBox(width: 8),
                          Text(
                            _recordingDurationString,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Merekam...',
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(width: 8),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 120),
                              child: TextField(
                                controller: _messageController,
                                focusNode: _focusNode,
                                onChanged: _onTyping,
                                style: TextStyle(color: isDark ? Colors.white : RupiaColors.textPrimary),
                                maxLines: null,
                                textInputAction: TextInputAction.newline,
                                decoration: InputDecoration(
                                  hintText: 'Ketik pesan',
                                  hintStyle: TextStyle(color: Colors.grey[500]),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ),
                          // Sticker icon inside the pill on the right end
                          IconButton(
                            icon: Icon(Icons.sticky_note_2_rounded, color: Colors.grey[500], size: 22),
                            onPressed: () => _showStickerPicker(context, isDark),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 8),
            // Right outside: Actions (Camera and Send/Mic)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!_isRecording) ...[
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 26),
                    onPressed: _pickCameraImage,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(bottom: 10, right: 10, left: 6),
                  ),
                ],
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _messageController,
                  builder: (context, value, child) {
                    final isTyping = value.text.isNotEmpty;
                    
                    return GestureDetector(
                      onLongPressStart: isTyping ? null : (_) => _startRecording(),
                      onLongPressEnd: isTyping ? null : (_) => _stopRecording(),
                      onTap: isTyping 
                          ? _sendMessage 
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tahan tombol mikrofon untuk merekam voice note'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.red : RupiaColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isTyping 
                              ? Icons.send 
                              : (_isRecording ? Icons.mic_rounded : Icons.mic_none_outlined),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ],
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
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161F24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 16,
          childAspectRatio: 0.82,
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
            _buildAttachmentItem(ctx, icon: Icons.insert_drive_file, color: Colors.deepPurpleAccent, label: 'Dokumen', isDev: false, onTap: () {
               Navigator.pop(ctx);
               Future.delayed(const Duration(milliseconds: 200), _pickPdfFile);
            }),
            _buildAttachmentItem(ctx, icon: Icons.headphones, color: Colors.orange, label: 'Audio', isDev: true),
            _buildAttachmentItem(ctx, icon: Icons.bar_chart, color: Colors.amber, label: 'Polling', isDev: true),
            _buildAttachmentItem(ctx, icon: Icons.event, color: Colors.redAccent, label: 'Acara', isDev: true),
          ],
        ),
      ),
    );
  }

  void _showStickerPicker(BuildContext context, bool isDark) {
    final List<String> stickers = [
      '🐻', '🐼', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧',
      '👍', '👎', '👏', '🙌', '🫶', '❤️', '🔥', '✨', '🎉', '💯',
      '😂', '😍', '😎', '😭', '😡', '😱', '🤔', '😴', '🥳', '🤯'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2B2B2B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Sticker Pack Eksklusif',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            SizedBox(
              height: 250,
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: stickers.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendSticker(stickers[index]);
                    },
                    child: Center(
                      child: Text(
                        stickers[index],
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendSticker(String stickerUrlOrEmoji) async {
    try {
      await widget.chatService.sendMessage(
        roomId: widget.roomId,
        senderId: widget.currentUid,
        text: stickerUrlOrEmoji,
        type: 'sticker',
      );
    } catch (e) {
      debugPrint('Error sending sticker: $e');
    }
  }

  Widget _buildAttachmentItem(BuildContext context, {required IconData icon, required Color color, required String label, required bool isDev, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        if (isDev) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text('$label masih dalam pengembangan'),
               backgroundColor: const Color(0xFF1E212A),
               duration: const Duration(seconds: 1),
             ),
           );
        } else {
           if (onTap != null) onTap();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isDark
                  ? (isDev ? const Color(0xFF1E232A) : const Color(0xFF252A30))
                  : (isDev ? Colors.grey[100] : Colors.grey[50]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? (isDev ? Colors.white.withOpacity(0.04) : Colors.white10)
                    : (isDev ? Colors.black.withOpacity(0.05) : Colors.black12),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    icon,
                    color: isDev ? color.withOpacity(0.4) : color,
                    size: 24,
                  ),
                ),
                if (isDev)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: isDark ? Colors.white30 : Colors.black38,
                      size: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? (isDev ? Colors.white38 : Colors.white70)
                  : (isDev ? Colors.black38 : Colors.black87),
              fontSize: 12,
              fontWeight: isDev ? FontWeight.normal : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String senderName;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.senderName,
  });

  bool _isEmojiOnly(String text) {
    if (text.isEmpty) return false;
    final t = text.replaceAll(RegExp(r'\s+'), '');
    if (t.isEmpty) return false;
    if (t.runes.length > 5) return false; // up to 3-5 emojis roughly
    return RegExp(r'^[\p{Emoji}\u200D\uFE0F]+$', unicode: true).hasMatch(t);
  }

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

    final isSticker = message.type == 'sticker';
    final isAudio = message.type == 'audio';
    final isImage = message.type == 'image';
    final isPdf = message.type == 'pdf';
    final isEmoji = !isSticker && !isAudio && !isCallLog && !isImage && !isPdf && _isEmojiOnly(displayContent);

    // Modern WhatsApp-style colors
    final Color bubbleColor = isMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB))
        : (isDark ? const Color(0xFF202C33) : Colors.white);
    
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color timeColor = isDark ? Colors.white54 : Colors.grey[600]!;

    final String timeStr = _formatTime(message.timestamp);

    // 1. Render Image WITHOUT caption
    if (isImage && (message.caption == null || message.caption!.isEmpty)) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.all(2),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isMe ? 12 : 0),
              topRight: Radius.circular(isMe ? 0 : 12),
              bottomLeft: const Radius.circular(12),
              bottomRight: const Radius.circular(12),
            ),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  ImageViewerDialog.show(
                    context,
                    message.text,
                    title: senderName,
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isMe ? 10 : 2),
                    topRight: Radius.circular(isMe ? 2 : 10),
                    bottomLeft: const Radius.circular(10),
                    bottomRight: const Radius.circular(10),
                  ),
                  child: Hero(
                    tag: message.text,
                    child: Image.network(
                      message.text,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: message.isRead ? Colors.blue : Colors.white,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Render Image WITH caption
    if (isImage && message.caption != null && message.caption!.isNotEmpty) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.all(4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isMe ? 12 : 0),
              topRight: Radius.circular(isMe ? 0 : 12),
              bottomLeft: const Radius.circular(12),
              bottomRight: const Radius.circular(12),
            ),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  ImageViewerDialog.show(
                    context,
                    message.text,
                    title: senderName,
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isMe ? 10 : 2),
                    topRight: Radius.circular(isMe ? 2 : 10),
                    bottomLeft: const Radius.circular(8),
                    bottomRight: const Radius.circular(8),
                  ),
                  child: Hero(
                    tag: message.text,
                    child: Image.network(
                      message.text,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.caption!,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: timeColor,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: 13,
                            color: message.isRead ? Colors.blue : timeColor,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Render all other types (text, sticker, audio, pdf, emoji)
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: (isSticker || isEmoji)
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
        decoration: (isSticker || isEmoji)
            ? null
            : BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMe ? 12 : 0),
                  topRight: Radius.circular(isMe ? 0 : 12),
                  bottomLeft: const Radius.circular(12),
                  bottomRight: const Radius.circular(12),
                ),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAudio)
              _AudioBubble(url: message.text, isMe: isMe)
            else if (isPdf)
              _PdfBubble(url: message.text, isMe: isMe)
            else if (isSticker)
              Text(
                displayContent,
                style: const TextStyle(fontSize: 60),
              )
            else
              Text(
                displayContent,
                style: TextStyle(
                  color: isEmoji ? null : textColor,
                  fontSize: isEmoji ? 45 : 15,
                  height: 1.3,
                  fontStyle: isCallLog ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: (isSticker || isEmoji)
                        ? (isDark ? Colors.white70 : Colors.black54)
                        : timeColor,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 13,
                    color: message.isRead ? Colors.blue : ((isSticker || isEmoji) ? Colors.grey : timeColor),
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

class _AudioBubble extends StatefulWidget {
  final String url;
  final bool isMe;

  const _AudioBubble({required this.url, required this.isMe});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.url));
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            color: widget.isMe ? Colors.white : RupiaColors.primary,
          ),
          onPressed: _togglePlay,
        ),
        SliderTheme(
          data: SliderThemeData(
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 2,
            activeTrackColor: widget.isMe ? Colors.white : RupiaColors.primary,
            inactiveTrackColor: widget.isMe ? Colors.white38 : Colors.grey[300],
            thumbColor: widget.isMe ? Colors.white : RupiaColors.primary,
          ),
          child: SizedBox(
            width: 120,
            child: Slider(
              min: 0,
              max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1,
              value: _position.inSeconds.toDouble(),
              onChanged: (value) async {
                final pos = Duration(seconds: value.toInt());
                await _audioPlayer.seek(pos);
              },
            ),
          ),
        ),
        Text(
          _formatDuration(_position.inSeconds > 0 ? _position : _duration),
          style: TextStyle(
            fontSize: 12,
            color: widget.isMe ? Colors.white : RupiaColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PdfBubble extends StatelessWidget {
  final String url;
  final bool isMe;

  const _PdfBubble({required this.url, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.isNotEmpty ? Uri.decodeComponent(uri.pathSegments.last) : 'dokumen.pdf';

    final cardColor = isMe 
        ? (isDark ? const Color(0xFF004D3F) : const Color(0xFFD9FDD3))
        : (isDark ? const Color(0xFF26353D) : Colors.grey.shade100);
    final titleColor = isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final subtitleColor = isMe ? Colors.white70 : (isDark ? Colors.white60 : Colors.black54);

    return InkWell(
      onTap: () async {
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (_) {}
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 36),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PDF • Ketuk untuk buka',
                    style: TextStyle(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashingRedDot extends StatefulWidget {
  const _FlashingRedDot();

  @override
  State<_FlashingRedDot> createState() => _FlashingRedDotState();
}

class _FlashingRedDotState extends State<_FlashingRedDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
    );
  }
}
