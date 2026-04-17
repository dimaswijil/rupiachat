class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final bool isOnline;
  final bool isArchived;
  final bool isPinned;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.isOnline = false,
    this.isArchived = false,
    this.isPinned = false,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime? parsedTime;
    if (map['last_message_time'] != null) {
      String raw = map['last_message_time'].toString();
      // Laravel returns UTC timestamps without 'Z' suffix (e.g. "2026-04-09 03:28:00").
      // DateTime.tryParse treats strings without timezone as local, which is incorrect.
      // Append 'Z' if no timezone info is present to force UTC interpretation.
      if (!raw.endsWith('Z') && !raw.contains('+') && !raw.contains(RegExp(r'-\d{2}:\d{2}$'))) {
        raw = '${raw.replaceAll(' ', 'T')}Z';
      }
      parsedTime = DateTime.tryParse(raw);
    }

    return UserModel(
      uid: map['id']?.toString() ?? map['uid']?.toString() ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      photoUrl: map['photo_url'] ?? map['photoUrl'],
      isOnline: map['is_online'] == 1 || map['is_online'] == true || map['isOnline'] == true,
      isArchived: map['is_archived'] == 1 || map['is_archived'] == true,
      isPinned: map['is_pinned'] == 1 || map['is_pinned'] == true,
      lastMessage: map['last_message'],
      lastMessageTime: parsedTime,
      unreadCount: map['unread_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'photo_url': photoUrl,
      'is_online': isOnline,
      'is_archived': isArchived,
      'is_pinned': isPinned,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'unread_count': unreadCount,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    bool? isOnline,
    bool? isArchived,
    bool? isPinned,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
