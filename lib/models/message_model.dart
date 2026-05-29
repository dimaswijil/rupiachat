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
  final String? caption;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    this.amount,
    required this.timestamp,
    this.isRead = false,
    this.status = 'sent',
    this.caption,
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
      caption: map['caption']?.toString(),
    );
  }

  // Copy with override
  MessageModel copyWith({
    String? id,
    String? senderId,
    String? text,
    String? type,
    String? amount,
    DateTime? timestamp,
    bool? isRead,
    String? status,
    String? caption,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      caption: caption ?? this.caption,
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
      if (caption != null) 'caption': caption,
    };
  }

  // Helper static untuk memformat pesan preview agar ramah pengguna (WhatsApp-style)
  static String formatPreview(String? rawMsg) {
    if (rawMsg == null || rawMsg.isEmpty) return 'Mulai percakapan...';
    
    // Format pesan call agar tidak tampil JSON mentah
    if (rawMsg.startsWith('{') && rawMsg.contains('call_type')) {
      if (rawMsg.contains('"video"')) {
        return '📹 Panggilan Video';
      } else {
        return '📞 Panggilan Suara';
      }
    }

    final lowerMsg = rawMsg.toLowerCase();

    // 1. Deteksi Cepat via Supabase Storage URL
    if (lowerMsg.contains('supabase.co/storage') || lowerMsg.contains('supabase.co')) {
      if (lowerMsg.contains('document') || lowerMsg.contains('pdf') || lowerMsg.contains('doc')) {
        return '📄 Dokumen PDF';
      }
      if (lowerMsg.contains('audio') || lowerMsg.contains('voice') || lowerMsg.contains('record') || lowerMsg.contains('.mp3') || lowerMsg.contains('.m4a')) {
        return '🎵 Rekaman Suara';
      }
      // Default untuk file lain di Supabase adalah Gambar/Foto
      return '📷 Gambar';
    }

    // 2. Gambar / Foto (Lokal/Laravel/Umum)
    if (rawMsg == '[Gambar]' ||
        lowerMsg.contains('storage/messages/') || 
        lowerMsg.contains('/messages/') ||
        lowerMsg.contains('.png') ||
        lowerMsg.contains('.jpg') ||
        lowerMsg.contains('.jpeg') ||
        lowerMsg.contains('.gif') ||
        lowerMsg.contains('.webp')) {
      return '📷 Gambar';
    }

    // 3. Dokumen / PDF (Lokal/Laravel/Umum)
    if (rawMsg == '[Dokumen PDF]' ||
        lowerMsg.contains('.pdf')) {
      return '📄 Dokumen PDF';
    }

    // 4. Audio / Rekaman Suara (Lokal/Laravel/Umum)
    if (lowerMsg.contains('.mp3') ||
        lowerMsg.contains('.wav') ||
        lowerMsg.contains('.m4a') ||
        lowerMsg.contains('.ogg')) {
      return '🎵 Rekaman Suara';
    }

    // 5. Stiker
    if (lowerMsg.contains('sticker') || lowerMsg.contains('stickers')) {
      return '🎨 Stiker';
    }

    return rawMsg;
  }
}
