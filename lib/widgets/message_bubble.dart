import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  final bool isRead;
  final String type;
  final String? id;
  final String status; // 'sending', 'sent', 'delivered', 'read'

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.time,
    this.isRead = false,
    this.type = 'text',
    this.id,
    this.status = 'sent',
  });

  Widget _getStatusIcon(bool isDarkMode) {
    Color greyColor = isDarkMode ? Colors.white54 : Colors.grey[600]!;
    switch (status) {
      case 'sending':
        return Icon(Icons.schedule, size: 13, color: greyColor);
      case 'sent':
        return Icon(Icons.done, size: 13, color: greyColor);
      case 'delivered':
        return Icon(Icons.done_all, size: 13, color: greyColor);
      case 'read':
        return const Icon(Icons.done_all, size: 13, color: Colors.blue);
      default:
        return Icon(Icons.done, size: 13, color: greyColor);
    }
  }

  bool _isEmojiOnly(String text) {
    if (text.isEmpty) return false;
    final t = text.replaceAll(RegExp(r'\s+'), '');
    if (t.isEmpty) return false;
    // Check if it's 1-3 emojis
    if (t.runes.length > 5) return false; // approximate length limit for a few emojis
    return RegExp(r'^[\p{Emoji}\u200D\uFE0F]+$', unicode: true).hasMatch(t);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Image type
    if (type == 'image') {
      return _buildImageBubble(context, isDarkMode);
    }

    final bool isEmoji = _isEmojiOnly(text);

    // WhatsApp colors
    final Color bubbleColor = isMe
        ? (isDarkMode ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB))
        : (isDarkMode ? const Color(0xFF202C33) : Colors.white);
        
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color timeColor = isDarkMode ? Colors.white54 : Colors.grey[600]!;

    // Text type — WhatsApp style (time inside bubble)
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: isEmoji 
            ? const EdgeInsets.fromLTRB(8, 4, 8, 4) 
            : const EdgeInsets.fromLTRB(10, 6, 8, 8),
        decoration: isEmoji ? null : BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 12 : 0),
            topRight: Radius.circular(isMe ? 0 : 12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
          boxShadow: isDarkMode ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            // Text content
            Text(
              text,
              style: TextStyle(
                color: isEmoji ? null : textColor,
                fontSize: isEmoji ? 45 : 15,
                height: 1.3,
              ),
            ),
            // Spacing
            SizedBox(width: isEmoji ? 8 : 6),
            // Time + status (inside bubble, bottom right)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 0),
              child: Container(
                padding: isEmoji ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : null,
                decoration: isEmoji ? BoxDecoration(
                  color: isDarkMode ? Colors.black54 : Colors.black38,
                  borderRadius: BorderRadius.circular(10),
                ) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: isEmoji ? Colors.white : timeColor,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 2),
                      isEmoji 
                          ? Icon(Icons.done_all, size: 13, color: status == 'read' ? Colors.blue : Colors.white)
                          : _getStatusIcon(isDarkMode),
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

  Widget _buildImageBubble(BuildContext context, bool isDarkMode) {
    // WhatsApp colors
    final Color bubbleColor = isMe
        ? (isDarkMode ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB))
        : (isDarkMode ? const Color(0xFF202C33) : Colors.white);
        
    final Color timeColor = isDarkMode ? Colors.white54 : Colors.grey[600]!;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 12 : 0),
            topRight: Radius.circular(isMe ? 0 : 12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
          boxShadow: isDarkMode ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Image
            GestureDetector(
              onTap: () {
                Navigator.push(context, PageRouteBuilder(
                  opaque: false,
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return FadeTransition(
                      opacity: animation,
                      child: Scaffold(
                        backgroundColor: Colors.black.withOpacity(0.9),
                        appBar: AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          iconTheme: const IconThemeData(color: Colors.white),
                        ),
                        body: Center(
                          child: InteractiveViewer(
                            child: id != null
                                ? Hero(tag: 'msg_$id', child: Image.network(text))
                                : Image.network(text),
                          ),
                        ),
                      ),
                    );
                  },
                ));
              },
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMe ? 10 : 2),
                  topRight: Radius.circular(isMe ? 2 : 10),
                  bottomLeft: const Radius.circular(10),
                  bottomRight: const Radius.circular(10),
                ),
                child: id != null
                    ? Hero(
                        tag: 'msg_$id',
                        child: Image.network(text, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(20),
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          },
                        ),
                      )
                    : Image.network(text, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(20),
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                      ),
              ),
            ),
            // Time inside bubble (below image)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: TextStyle(
                    fontSize: 11,
                    color: timeColor,
                  )),
                  if (isMe) ...[
                    const SizedBox(width: 2),
                    _getStatusIcon(isDarkMode),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
