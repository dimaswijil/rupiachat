import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../services/supabase_storage_service.dart'; // Tambahkan ini
import '../../models/group_model.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/image_viewer_dialog.dart';
import '../../utils/colors.dart';
import '../chat/photo_confirm_screen.dart';
import '../call/group_call_screen.dart';
import '../../widgets/call_bubble.dart';
import '../../services/call_api_service.dart';
import 'group_info_screen.dart';

/// Chat room untuk grup — mirip dengan ChatRoomScreen tapi untuk grup
class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupPhoto;
  final String currentUid;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupPhoto,
    required this.currentUid,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  final _groupService = GroupService();

  List<GroupMessageModel> _messages = [];
  bool _loading = true;
  StreamSubscription? _subscription;
  late String _groupName;
  String? _groupPhoto;

  @override
  void initState() {
    super.initState();
    _groupName = widget.groupName;
    _groupPhoto = widget.groupPhoto;
    _initToken();
  }

  Future<void> _initToken() async {
    final token = await AuthService().currentToken ?? '';
    _groupService.setToken(token);
    await _loadHistory();
    _listenRealtime();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final messages = await _groupService.loadMessages(widget.groupId);
    if (!mounted) return;
    setState(() {
      _messages = messages.reversed.toList();
      _loading = false;
    });
  }

  void _listenRealtime() {
    _subscription =
        _groupService.listenMessages(widget.groupId).listen((newMsg) {
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
        });
      }
    });
  }


  Future<void> _handlePhotoSend(String filePath) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoConfirmScreen(
          imagePath: filePath,
          title: widget.groupName,
        ),
      ),
    );

    if (result != null && result['confirmed'] == true) {
      final String? caption = result['caption'];
      try {
        await _groupService.sendImage(
          groupId: widget.groupId,
          filePath: filePath,
          caption: caption,
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

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _handlePhotoSend(image.path);
    }
  }

  Future<void> _pickCameraImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      _handlePhotoSend(image.path);
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

        // 2. Kirim URL publik tersebut ke Laravel API Grup
        await _groupService.sendMessage(
          groupId: widget.groupId,
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Optimistic UI: tambahkan dulu ke list
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final currentName = await AuthService().currentName ?? 'Anda';
    final currentPhoto = await AuthService().currentPhoto;
    
    final tempMsg = GroupMessageModel(
      id: tempId,
      groupId: widget.groupId,
      senderId: widget.currentUid,
      senderName: currentName,
      senderPhoto: currentPhoto,
      text: text,
      type: 'text',
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.insert(0, tempMsg);
      _controller.clear();
    });

    try {
      await _groupService.sendMessage(
        groupId: widget.groupId,
        text: text,
      );
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

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? RupiaColors.cardDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _GroupInfoSheet(
        groupId: widget.groupId,
        groupService: _groupService,
        currentUid: widget.currentUid,
        onLeft: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
        onUpdated: (name, photo) {
          setState(() {
            _groupName = name;
            if (photo != null) _groupPhoto = photo;
          });
        },
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
          decoration: BoxDecoration(
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
            title: InkWell(
              onTap: _showGroupInfo,
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    image: _groupPhoto != null
                        ? DecorationImage(
                            image: NetworkImage(_groupPhoto!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _groupPhoto == null
                      ? const Icon(Icons.group, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _groupName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Ketuk untuk info grup',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.videocam_outlined, color: Colors.white, size: 26),
                tooltip: 'Video Call Grup',
                onPressed: () => _startGroupCall(isVideo: true),
              ),
              IconButton(
                icon: const Icon(Icons.call_outlined, color: Colors.white, size: 24),
                tooltip: 'Voice Call Grup',
                onPressed: () => _startGroupCall(isVideo: false),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white, size: 26),
                onSelected: (val) async {
                  if (val == 'info') {
                    final res = await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => GroupInfoScreen(
                        groupId: widget.groupId,
                        currentUid: widget.currentUid,
                      ),
                    ));
                    if (res == 'left' || res == 'deleted') {
                      if (mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'info',
                    child: Text('Info Grup'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(color: RupiaColors.primary))
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: RupiaColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.group,
                                size: 32, color: RupiaColors.primary),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.groupName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: isDarkMode
                                  ? Colors.white
                                  : RupiaColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Belum ada pesan, mulai percakapan!',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white54
                                  : RupiaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        final isMe = msg.senderId == widget.currentUid;
                        final time = DateFormat('HH:mm')
                            .format(msg.timestamp.toLocal());

                        // Date separator: show when day changes
                        final msgDate = msg.timestamp.toLocal();
                        final prevDate = i < _messages.length - 1
                            ? _messages[i + 1].timestamp.toLocal()
                            : null;
                        final showDate = prevDate == null ||
                            msgDate.year != prevDate.year ||
                            msgDate.month != prevDate.month ||
                            msgDate.day != prevDate.day;

                        // Show sender name for group messages (only for others)
                        final showSenderName = !isMe &&
                            (i == _messages.length - 1 ||
                                _messages[i + 1].senderId != msg.senderId);

                        final isCallMsg = msg.type == 'call' || msg.text.startsWith('📞') || msg.text.startsWith('📹') ||
                            (msg.text.startsWith('{') && msg.text.contains('call_type'));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDate)
                              _DateSeparator(
                                label: _dateLabel(msgDate),
                                isDarkMode: isDarkMode,
                              ),
                            if (isCallMsg)
                              _buildGroupCallBubble(msg, isMe, time, showSenderName ? msg.senderName : null, isDarkMode)
                            else
                              _GroupMessageBubble(
                                text: msg.text,
                                isMe: isMe,
                                time: time,
                                senderName:
                                    showSenderName ? msg.senderName : null,
                                senderPhoto: msg.senderPhoto,
                                type: msg.type,
                                isDarkMode: isDarkMode,
                                caption: msg.caption,
                              ),
                          ],
                        );
                      },
                    ),
        ),
        // Input area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Colors.transparent,
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2B2B2B) : Colors.white,
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
                              controller: _controller,
                              style: TextStyle(color: isDarkMode ? Colors.white : RupiaColors.textPrimary),
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
                          onPressed: () => _showAttachmentMenu(context, isDarkMode),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
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
                  valueListenable: _controller,
                  builder: (context, value, child) {
                    final isTyping = value.text.isNotEmpty;
                    return GestureDetector(
                      onTap: isTyping ? _sendMessage : null,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
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
        ),
      ]),
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

  void _startGroupCall({required bool isVideo}) async {
    final callType = isVideo ? 'video' : 'voice';
    // Kirim pesan call ke grup
    try {
      await _groupService.sendMessage(
        groupId: widget.groupId,
        text: '{"call_type":"$callType","status":"missed","duration":0}',
        type: 'call',
      );
      
      // Kirim FCM ke semua anggota grup
      await CallApiService().sendGroupCallFcm(
        groupId: widget.groupId,
        channelName: widget.groupId, // channelName sama dengan groupId
        isVideoCall: isVideo,
        groupName: _groupName,
      );
    } catch (_) {}
    if (mounted) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => GroupCallScreen(
          channelName: widget.groupId,
          groupName: _groupName,
          isVideoCall: isVideo,
        ),
      ));
    }
  }

  Widget _buildGroupCallBubble(GroupMessageModel msg, bool isMe, String time, String? senderName, bool isDarkMode) {
    bool isVideo = false;
    String callStatus = 'missed';
    int callDuration = 0;

    if (msg.text.startsWith('{')) {
      try {
        isVideo = msg.text.contains('"video"');
        if (msg.text.contains('"answered"')) callStatus = 'answered';
        final durMatch = RegExp(r'"duration":(\d+)').firstMatch(msg.text);
        if (durMatch != null) callDuration = int.tryParse(durMatch.group(1)!) ?? 0;
      } catch (_) {}
    } else {
      isVideo = msg.text.startsWith('📹');
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 4, left: isMe ? 48 : 0, right: isMe ? 0 : 48),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (senderName != null && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 2),
              child: Text(senderName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _senderColor(senderName))),
            ),
          CallBubble(
            isMe: isMe,
            isVideo: isVideo,
            status: callStatus,
            duration: callDuration,
            time: time,
          ),
        ],
      ),
    );
  }

  Color _senderColor(String name) {
    const colors = [
      Color(0xFF25D366), Color(0xFF34B7F1), Color(0xFFFF6B6B),
      Color(0xFFFFA726), Color(0xFFAB47BC), Color(0xFF26A69A),
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }
}

// ── Date label helper ───────────────────────────────────────
String _dateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(date.year, date.month, date.day);

  if (d == today) return 'Hari ini';
  if (d == yesterday) return 'Kemarin';

  // Same year → "Sab, 7 Mar"
  // Different year → "Sab, 7 Mar 2024"
  final pattern = d.year == now.year ? 'EEE, d MMM' : 'EEE, d MMM yyyy';
  return DateFormat(pattern, 'id').format(date);
}

// ── Date Separator widget ────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final String label;
  final bool isDarkMode;

  const _DateSeparator({required this.label, required this.isDarkMode});

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

// ── Bubble pesan grup (WhatsApp-style) ─────────────────────
class _GroupMessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  final String? senderName;
  final String? senderPhoto;
  final String type;
  final bool isDarkMode;
  final String? caption;

  const _GroupMessageBubble({
    required this.text,
    required this.isMe,
    required this.time,
    this.senderName,
    this.senderPhoto,
    required this.type,
    required this.isDarkMode,
    this.caption,
  });

  // Warna sender — vivid & unik per nama
  Color _senderColor(String name) {
    const colors = [
      Color(0xFF25D366), // hijau WA
      Color(0xFF34B7F1), // biru muda
      Color(0xFFFF6B6B), // merah muda
      Color(0xFFFFA726), // oranye
      Color(0xFFAB47BC), // ungu
      Color(0xFF26A69A), // teal
      Color(0xFFEC407A), // pink
      Color(0xFF42A5F5), // biru
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isImage = type == 'image' && text.startsWith('http');
    final isPdf = type == 'pdf';
    final showAvatar = senderName != null && !isMe;

    return Padding(
      padding: EdgeInsets.only(
        bottom: senderName != null ? 6 : 2, // lebih rapat kalau sender sama
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar — hanya tampil saat sender baru
          if (!isMe)
            SizedBox(
              width: 32,
              child: showAvatar
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: AvatarWidget(
                        name: senderName!,
                        size: 26,
                        photoUrl: senderPhoto,
                      ),
                    )
                  : null,
            ),
          if (!isMe) const SizedBox(width: 4),

          Flexible(
            child: Container(
              padding: isImage
                  ? (caption != null && caption!.isNotEmpty
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.all(2))
                  : EdgeInsets.fromLTRB(
                      10,
                      senderName != null && !isMe ? 6 : 8,
                      10,
                      6,
                    ),
              decoration: BoxDecoration(
                color: isMe
                    ? RupiaColors.primary
                    : (isDarkMode
                        ? const Color(0xFF1F2C34)
                        : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(
                      !isMe && senderName != null ? 4 : 12),
                  topRight: Radius.circular(
                      isMe && senderName != null ? 4 : 12),
                  bottomLeft: const Radius.circular(12),
                  bottomRight: const Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sender name (compact)
                  if (senderName != null && !isMe)
                    Padding(
                      padding: isImage
                          ? const EdgeInsets.fromLTRB(6, 4, 6, 6)
                          : const EdgeInsets.only(bottom: 2),
                      child: Text(
                        senderName!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _senderColor(senderName!),
                        ),
                      ),
                    ),

                  // Content + time inline
                  if (isImage)
                    if (caption != null && caption!.isNotEmpty)
                      // WITH Caption
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              ImageViewerDialog.show(
                                context,
                                text,
                                title: senderName ?? 'Grup',
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Hero(
                                tag: text,
                                child: Image.network(
                                  text,
                                  width: 240,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 240,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.white10
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              caption!,
                              style: TextStyle(
                                color: isMe ? Colors.white : (isDarkMode ? Colors.white.withOpacity(0.87) : Colors.black87),
                                fontSize: 15,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4, bottom: 2),
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe
                                      ? Colors.white60
                                      : (isDarkMode
                                          ? Colors.white30
                                          : RupiaColors.textHint),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      // WITHOUT Caption
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              ImageViewerDialog.show(
                                context,
                                text,
                                title: senderName ?? 'Grup',
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Hero(
                                tag: text,
                                child: Image.network(
                                  text,
                                  width: 240,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 240,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.white10
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                time,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                  else if (isPdf)
                    _buildPdfBubble(context, text, isMe, isDarkMode, time)
                  else
                    // Text + time in same row (WhatsApp style)
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(
                          text,
                          style: TextStyle(
                            color: isMe
                                ? Colors.white
                                : (isDarkMode
                                    ? const Color(0xFFE9EDEF)
                                    : RupiaColors.textPrimary),
                            fontSize: 14.5,
                            height: 1.3,
                          ),
                        ),
                        // Spacer invisible agar time tidak terlalu nempel
                        const SizedBox(width: 8),
                        // Time badge
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            time,
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? Colors.white60
                                  : (isDarkMode
                                      ? Colors.white30
                                      : RupiaColors.textHint),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfBubble(BuildContext context, String text, bool isMe, bool isDarkMode, String time) {
    final uri = Uri.parse(text);
    final fileName = uri.pathSegments.isNotEmpty ? Uri.decodeComponent(uri.pathSegments.last) : 'dokumen.pdf';
    final cardColor = isMe 
        ? (isDarkMode ? const Color(0xFF004D3F) : const Color(0xFFD9FDD3))
        : (isDarkMode ? const Color(0xFF26353D) : Colors.grey.shade100);
    final titleColor = isMe ? Colors.white : (isDarkMode ? Colors.white : Colors.black87);
    final subtitleColor = isMe ? Colors.white70 : (isDarkMode ? Colors.white60 : Colors.black54);
    
    return InkWell(
      onTap: () async {
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (_) {}
      },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white60 : (isDarkMode ? Colors.white30 : RupiaColors.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Group Info Bottom Sheet (Enhanced) ──────────────────────
class _GroupInfoSheet extends StatefulWidget {
  final String groupId;
  final GroupService groupService;
  final String currentUid;
  final VoidCallback onLeft;
  final Function(String name, String? photo)? onUpdated;

  const _GroupInfoSheet({
    required this.groupId,
    required this.groupService,
    required this.currentUid,
    required this.onLeft,
    this.onUpdated,
  });

  @override
  State<_GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends State<_GroupInfoSheet> {
  GroupModel? _group;
  bool _loading = true;
  bool _isAdmin = false;
  final _picker = ImagePicker();

  // ── Inline description editing ───────────────────────────
  bool _editingDesc = false;
  bool _descSaving = false;
  final _descCtrl = TextEditingController();
  final _descFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadGroupDetail();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  Future<void> _loadGroupDetail() async {
    final group = await widget.groupService.getGroupDetail(widget.groupId);
    if (mounted) {
      setState(() {
        _group = group;
        _loading = false;
        // Admin or Creator can edit
        _isAdmin = group?.myRole == 'admin' || group?.creatorId == widget.currentUid;
      });
    }
  }

  // ── Edit Nama Grup ────────────────────────────────────────
  void _editName() {
    final ctrl = TextEditingController(text: _group?.name ?? '');
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? RupiaColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Nama Grup',
            style: TextStyle(
                color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
                fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(
              color: isDarkMode ? Colors.white : RupiaColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Nama grup',
            hintStyle: TextStyle(
                color: isDarkMode ? Colors.white38 : RupiaColors.textHint),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: RupiaColors.primary, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: TextStyle(
                    color:
                        isDarkMode ? Colors.white54 : RupiaColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty && newName != _group?.name) {
                Navigator.pop(ctx);
                final ok = await widget.groupService
                    .updateGroup(widget.groupId, name: newName);
                if (ok) {
                  await _loadGroupDetail();
                  widget.onUpdated?.call(newName, _group?.photo);
                }
              }
            },
            child: Text('Simpan',
                style: TextStyle(
                    color: RupiaColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Mulai inline-edit deskripsi ──────────────────────────
  void _startEditDesc() {
    _descCtrl.text = _group?.description ?? '';
    setState(() => _editingDesc = true);
    // Autofocus after frame
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _descFocus.requestFocus();
    });
  }

  // ── Simpan deskripsi (inline) ─────────────────────────────
  Future<void> _saveDesc() async {
    if (_descSaving) return;
    // Cache messenger before async gap
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _descSaving = true);
    final newDesc = _descCtrl.text.trim();
    final ok = await widget.groupService.updateGroup(
      widget.groupId,
      description: newDesc,
    );
    if (!mounted) return;
    setState(() {
      _editingDesc = false;
      _descSaving = false;
    });
    if (ok) {
      await _loadGroupDetail();
      widget.onUpdated?.call(_group?.name ?? '', _group?.photo);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Deskripsi grup diperbarui'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui deskripsi'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Batal edit deskripsi ──────────────────────────────────
  void _cancelEditDesc() {
    _descFocus.unfocus();
    setState(() {
      _editingDesc = false;
      _descSaving = false;
    });
  }

  // ── Ganti Foto Grup ───────────────────────────────────────
  Future<void> _pickPhoto() async {
    // Let user pick from gallery OR camera
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? RupiaColors.cardDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: RupiaColors.primary),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading:
                  Icon(Icons.camera_alt_outlined, color: RupiaColors.primary),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (image != null) {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Group photo is square
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Tata Letak Foto',
            toolbarColor: RupiaColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Tata Letak Foto',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        // Show uploading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text('Mengunggah foto...'),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 10),
            ),
          );
        }

        final url = await widget.groupService.updatePhoto(widget.groupId, croppedFile.path);

        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (url != null) {
          // Update parent first with the confirmed URL
          final currentName = _group?.name ?? '';
          widget.onUpdated?.call(currentName, url);
          // Then reload detail for this sheet
          await _loadGroupDetail();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Foto grup diperbarui ✓'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gagal mengunggah foto'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollCtrl) {
        if (_loading) {
          return Center(
              child: CircularProgressIndicator(color: RupiaColors.primary));
        }

        if (_group == null) {
          return Center(
              child: Text('Gagal memuat info grup',
                  style: TextStyle(
                      color: isDarkMode
                          ? Colors.white54
                          : RupiaColors.textSecondary)));
        }

        return ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(0),
          children: [
            // ── Handle ──────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : RupiaColors.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Foto Grup ───────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _isAdmin ? _pickPhoto : null,
                child: Stack(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: RupiaColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                        image: _group!.photo != null
                            ? DecorationImage(
                                image: NetworkImage(_group!.photo!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _group!.photo == null
                          ? Icon(Icons.group,
                              size: 42, color: RupiaColors.primary)
                          : null,
                    ),
                    if (_isAdmin)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: RupiaColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDarkMode
                                  ? RupiaColors.cardDark
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Nama Grup (tappable jika admin) ─────────────
            GestureDetector(
              onTap: _isAdmin ? _editName : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _group!.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.edit,
                        size: 16,
                        color: isDarkMode
                            ? Colors.white38
                            : RupiaColors.textSecondary),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ── Jumlah anggota ──────────────────────────────
            Center(
              child: Text(
                'Grup · ${_group!.members.length} anggota',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.white38 : RupiaColors.textHint,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Deskripsi (inline editable) ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _editingDesc
                      ? (isDarkMode
                          ? Colors.white.withOpacity(0.08)
                          : Colors.white)
                      : (isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade50),
                  borderRadius: BorderRadius.circular(12),
                  border: _editingDesc
                      ? Border.all(color: RupiaColors.primary, width: 1.5)
                      : Border.all(color: Colors.transparent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label row
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16,
                            color: _editingDesc
                                ? RupiaColors.primary
                                : (isDarkMode
                                    ? Colors.white38
                                    : RupiaColors.textSecondary)),
                        const SizedBox(width: 8),
                        Text(
                          'Deskripsi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _editingDesc
                                ? RupiaColors.primary
                                : (isDarkMode
                                    ? Colors.white38
                                    : RupiaColors.textSecondary),
                          ),
                        ),
                        const Spacer(),
                        // Edit icon — only show when not already editing
                        if (_isAdmin && !_editingDesc)
                          GestureDetector(
                            onTap: _startEditDesc,
                            child: Icon(Icons.edit,
                                size: 14,
                                color: isDarkMode
                                    ? Colors.white24
                                    : RupiaColors.textHint),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Content: either TextField or static text
                    if (_editingDesc) ...
                      [
                        TextField(
                          controller: _descCtrl,
                          focusNode: _descFocus,
                          maxLines: null,
                          maxLength: 500,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? const Color(0xFFE9EDEF)
                                : RupiaColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tambah deskripsi grup...',
                            hintStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.white38
                                    : RupiaColors.textHint),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            counterStyle: TextStyle(
                              fontSize: 10,
                              color: isDarkMode
                                  ? Colors.white38
                                  : RupiaColors.textHint,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Action buttons inline
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed:
                                  _descSaving ? null : _cancelEditDesc,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Batal',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : RupiaColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: _descSaving ? null : _saveDesc,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                backgroundColor:
                                    RupiaColors.primary.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _descSaving
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: RupiaColors.primary),
                                    )
                                  : Text(
                                      'Simpan',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: RupiaColors.primary,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ]
                    else
                      GestureDetector(
                        onTap: _isAdmin ? _startEditDesc : null,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          _group!.description?.isNotEmpty == true
                              ? _group!.description!
                              : _isAdmin
                                  ? 'Ketuk untuk tambah deskripsi...'
                                  : 'Belum ada deskripsi',
                          style: TextStyle(
                            fontSize: 14,
                            color: _group!.description?.isNotEmpty == true
                                ? (isDarkMode
                                    ? const Color(0xFFE9EDEF)
                                    : RupiaColors.textPrimary)
                                : (isDarkMode
                                    ? Colors.white24
                                    : RupiaColors.textHint),
                            fontStyle:
                                _group!.description?.isNotEmpty == true
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Divider ─────────────────────────────────────
            Divider(
                height: 1,
                color: isDarkMode ? Colors.white10 : Colors.grey.shade200),

            // ── Anggota Header ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.people_outline,
                      size: 18,
                      color: isDarkMode
                          ? Colors.white54
                          : RupiaColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    '${_group!.members.length} Anggota',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white70
                          : RupiaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // ── Daftar Anggota ──────────────────────────────
            ..._group!.members.map((member) {
              final isCreator = member.id == _group!.creatorId;
              final isAdmin = member.role == 'admin';
              final isYou = member.id == widget.currentUid;

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8),
                  leading: Stack(
                    children: [
                      AvatarWidget(
                        name: member.name,
                        size: 44,
                        photoUrl: member.photoUrl,
                        interactive: true,
                        heroTag: 'group_info_${member.id}',
                      ),
                      if (member.isOnline)
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
                                    ? RupiaColors.cardDark
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    isYou ? '${member.name} (Anda)' : member.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    member.phone ?? member.email ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.white38
                          : RupiaColors.textSecondary,
                    ),
                  ),
                  trailing: (isCreator || isAdmin)
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCreator
                                ? RupiaColors.primary.withOpacity(0.12)
                                : RupiaColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isCreator ? 'Admin' : 'Admin',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isCreator
                                  ? RupiaColors.primary
                                  : RupiaColors.textSecondary,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            }),

            const SizedBox(height: 8),
            Divider(
                height: 1,
                color: isDarkMode ? Colors.white10 : Colors.grey.shade200),

            // ── Keluar Grup ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.exit_to_app,
                      color: Colors.red, size: 22),
                ),
                title: const Text(
                  'Keluar dari Grup',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor:
                          isDarkMode ? RupiaColors.cardDark : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: Text('Keluar Grup',
                          style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white
                                  : RupiaColors.textPrimary)),
                      content: Text(
                          'Apakah Anda yakin ingin keluar dari grup ini?',
                          style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : RupiaColors.textSecondary)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Batal',
                              style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white54
                                      : RupiaColors.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Keluar',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final success = await widget.groupService
                        .leaveGroup(widget.groupId);
                    if (success) {
                      widget.onLeft();
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

