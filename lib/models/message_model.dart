// ─────────────────────────────────────────────
//  Model untuk satu pesan chat
//  Semua data pesan mengikuti struktur ini
// ─────────────────────────────────────────────

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final String type;
  final String? amount;
  final DateTime timestamp;
  final bool isRead;
  final String status; // 'sending', 'sent', 'delivered', 'read'

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    this.amount,
    required this.timestamp,
    this.isRead = false,
    this.status = 'sent',
  });

  // Dari Laravel API response (snake_case + ISO 8601 timestamp)
  factory MessageModel.fromMap(Map<String, dynamic> map, String docId) {
    return MessageModel(
      id: docId,
      senderId: map['sender_id']?.toString() ?? map['senderId']?.toString() ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      amount: map['amount']?.toString(),
      timestamp: (() {
        if (map['created_at'] != null) {
          String raw = map['created_at'].toString();
          // Laravel may return UTC timestamps without 'Z' suffix.
          // Force UTC interpretation if no timezone info is present.
          if (!raw.endsWith('Z') && !raw.contains('+') && !raw.contains(RegExp(r'-\d{2}:\d{2}$'))) {
            raw = '${raw.replaceAll(' ', 'T')}Z';
          }
          return DateTime.parse(raw);
        }
        return DateTime.now();
      })(),
      isRead: map['is_read']?.toString() == '1' || 
              map['is_read'] == true || 
              map['is_read']?.toString() == 'true',
      status: (map['is_read']?.toString() == '1' || map['is_read'] == true) ? 'read' : 'sent',
    );
  }

  // Untuk kirim ke Laravel (POST body)
  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'text': text,
      'type': type,
      'amount': amount,
      'is_read': isRead,
    };
  }
}
