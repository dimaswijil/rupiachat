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
        return const Icon(Icons.schedule, size: 12, color: RupiaColors.textHint);
      case 'sent':
        return const Icon(Icons.done, size: 12, color: RupiaColors.textHint);
      case 'delivered':
        return const Icon(Icons.done_all, size: 12, color: RupiaColors.textHint);
      case 'read':
        return const Icon(Icons.done_all, size: 12, color: Colors.blue);
      default:
        return const Icon(Icons.done, size: 12, color: RupiaColors.textHint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: type == 'image' ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe 
                  ? RupiaColors.primary 
                  : (isDarkMode ? RupiaColors.cardDark : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: isDarkMode ? null : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: type == 'image'
                ? GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
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
                        ),
                      );
                    },
                    child: id != null ? Hero(
                      tag: 'msg_$id',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          text,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Padding(
                            padding: EdgeInsets.all(20),
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          },
                        ),
                      ),
                    ) : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        text,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Padding(
                          padding: EdgeInsets.all(20),
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                      ),
                    ),
                  )
                : Text(
                    text, 
                    style: TextStyle(
                      color: isMe ? Colors.white : (isDarkMode ? Colors.white : RupiaColors.textPrimary), 
                      fontSize: 14
                    )
                  ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: const TextStyle(fontSize: 10, color: RupiaColors.textHint)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _getStatusIcon(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
