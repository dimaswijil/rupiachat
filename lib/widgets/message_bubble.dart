import 'package:flutter/material.dart';
import '../utils/colors.dart';

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

  Widget _getStatusIcon() {
    switch (status) {
      case 'sending':
        return const Icon(Icons.schedule, size: 13, color: Colors.white60);
      case 'sent':
        return Icon(Icons.done, size: 13, color: isMe ? Colors.white60 : RupiaColors.textHint);
      case 'delivered':
        return Icon(Icons.done_all, size: 13, color: isMe ? Colors.white60 : RupiaColors.textHint);
      case 'read':
        return Icon(Icons.done_all, size: 13, color: isMe ? const Color(0xFF86EFAC) : Colors.blue);
      default:
        return Icon(Icons.done, size: 13, color: isMe ? Colors.white60 : RupiaColors.textHint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Image type
    if (type == 'image') {
      return _buildImageBubble(context, isDarkMode);
    }

    // Text type — WhatsApp style (time inside bubble)
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
        decoration: BoxDecoration(
          color: isMe
              ? RupiaColors.primary
              : (isDarkMode ? RupiaColors.cardDark : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: isDarkMode ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
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
                color: isMe ? Colors.white : (isDarkMode ? Colors.white : RupiaColors.textPrimary),
                fontSize: 15,
                height: 1.35,
              ),
            ),
            // Spacing
            const SizedBox(width: 6),
            // Time + status (inside bubble, bottom right)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white54 : (isDarkMode ? Colors.white38 : RupiaColors.textHint),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    _getStatusIcon(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBubble(BuildContext context, bool isDarkMode) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
        decoration: BoxDecoration(
          color: isMe
              ? RupiaColors.primary
              : (isDarkMode ? RupiaColors.cardDark : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: isDarkMode ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
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
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMe ? 14 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 14),
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
                    color: isMe ? Colors.white54 : (isDarkMode ? Colors.white38 : RupiaColors.textHint),
                  )),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    _getStatusIcon(),
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
