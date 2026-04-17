class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? photo;
  final String creatorId;
  final String? creatorName;
  final int memberCount;
  final String? myRole;
  final bool isPinned;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final List<GroupMemberModel> members;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.photo,
    required this.creatorId,
    this.creatorName,
    this.memberCount = 0,
    this.myRole,
    this.isPinned = false,
    this.lastMessage,
    this.lastMessageTime,
    this.members = const [],
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    DateTime? parsedTime;
    if (map['last_message_time'] != null) {
      String raw = map['last_message_time'].toString();
      if (!raw.endsWith('Z') && !raw.contains('+') && !raw.contains(RegExp(r'-\d{2}:\d{2}$'))) {
        raw = '${raw.replaceAll(' ', 'T')}Z';
      }
      parsedTime = DateTime.tryParse(raw);
    }

    List<GroupMemberModel> membersList = [];
    if (map['members'] != null && map['members'] is List) {
      membersList = (map['members'] as List)
          .map((m) => GroupMemberModel.fromMap(m))
          .toList();
    }

    return GroupModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      photo: map['photo'],
      creatorId: map['creator_id']?.toString() ?? '',
      creatorName: map['creator_name'],
      memberCount: map['member_count'] ?? 0,
      myRole: map['my_role'],
      isPinned: map['is_pinned'] == 1 || map['is_pinned'] == true,
      lastMessage: map['last_message'],
      lastMessageTime: parsedTime,
      members: membersList,
    );
  }
}

class GroupMemberModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final bool isOnline;
  final String role;

  GroupMemberModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.isOnline = false,
    this.role = 'member',
  });

  factory GroupMemberModel.fromMap(Map<String, dynamic> map) {
    return GroupMemberModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      email: map['email'],
      phone: map['phone'],
      photoUrl: map['photo_url'],
      isOnline: map['is_online'] == 1 || map['is_online'] == true,
      role: map['role'] ?? 'member',
    );
  }
}

class GroupMessageModel {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String text;
  final String type;
  final String? amount;
  final String? mediaUrl;
  final DateTime timestamp;

  GroupMessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.text,
    required this.type,
    this.amount,
    this.mediaUrl,
    required this.timestamp,
  });

  factory GroupMessageModel.fromMap(Map<String, dynamic> map) {
    return GroupMessageModel(
      id: map['id']?.toString() ?? '',
      groupId: map['group_id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      senderName: map['sender_name'] ?? 'Unknown',
      senderPhoto: map['sender_photo'],
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      amount: map['amount']?.toString(),
      mediaUrl: map['media_url'],
      timestamp: (() {
        if (map['created_at'] != null) {
          String raw = map['created_at'].toString();
          if (!raw.endsWith('Z') && !raw.contains('+') && !raw.contains(RegExp(r'-\d{2}:\d{2}$'))) {
            raw = '${raw.replaceAll(' ', 'T')}Z';
          }
          return DateTime.parse(raw);
        }
        return DateTime.now();
      })(),
    );
  }
}
