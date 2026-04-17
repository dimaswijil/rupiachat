import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  static const _baseUrl = 'http://192.168.112.18:8000';

  final _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  ChatService._internal();

  // === PUSHER ULTIMATE SINGLETON ===
  static final _pusher = PusherChannelsFlutter.getInstance();
  static final StreamController<PusherEvent> _globalEventController = StreamController<PusherEvent>.broadcast();
  static bool _pusherInitialized = false;
  static final Set<String> _subscribedChannels = {};

  static Future<void> initPusher() async {
    // Selalu panggil connect untuk memastikan status aktif
    if (_pusherInitialized) {
      try {
        await _pusher.connect();
      } catch (_) {}
      return;
    }

    try {
      print('[Pusher] Initializing core pipeline...');
      await _pusher.init(
        apiKey: 'fd71e26c996be8a21eef',
        cluster: 'ap1',
        // ✅ STRATEGI PALING STABIL: Satu handler global di init.
        // Handler ini akan menangkap SEMUA event dari SEMUA channel yang di-subscribe.
        onEvent: (event) {
          print('[Pusher] Incoming: ${event.channelName} -> ${event.eventName}');
          _globalEventController.add(event);
        },
        onConnectionStateChange: (state, prev) {
          print('[Pusher] Connection changed: $prev -> $state');
        },
        onError: (msg, code, e) {
          print('[Pusher] Connection Error: $msg ($code)');
        },
      );
      await _pusher.connect();
      _pusherInitialized = true;
      print('[Pusher] Core pipeline ready ✅');
    } catch (e) {
      print('[Pusher] Critical Init Error: $e');
    }
  }

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  String getRoomId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  // === REALTIME LISTENERS ===

  Stream<MessageModel> listenMessages(String roomId) {
    final channelName = 'chat.$roomId';
    initPusher();
    
    // Subscribe sekali saja ke channel ini
    if (!_subscribedChannels.contains(channelName)) {
      _pusher.subscribe(channelName: channelName);
      _subscribedChannels.add(channelName);
      print('[Pusher] Subscribed to $channelName');
    }

    // Return a filtered, deduplicated stream from the global broadcaster
    return _globalEventController.stream
        .where((event) => event.channelName == channelName)
        .where((event) => event.eventName == 'MessageSent' || event.eventName == 'App\\Events\\MessageSent')
        .map((event) {
          try {
            final data = jsonDecode(event.data);
            if (data['message'] != null) {
              return MessageModel.fromMap(data['message'], data['message']['id'].toString());
            }
          } catch (e) {
            print('[Pusher] Message Parse Error: $e');
          }
          return null;
        })
        .where((msg) => msg != null)
        .cast<MessageModel>();
  }

  Stream<void> listenGlobalNotifications(String currentUid) {
    final channelName = 'user.$currentUid';
    initPusher();
    
    if (!_subscribedChannels.contains(channelName)) {
      _pusher.subscribe(channelName: channelName);
      _subscribedChannels.add(channelName);
      print('[Pusher] Subscribed to $channelName');
    }

    return _globalEventController.stream
        .where((event) => event.channelName == channelName)
        .where((event) => event.eventName == 'MessageSent' || event.eventName == 'App\\Events\\MessageSent')
        .map((_) => null);
  }

  Stream<Map<String, dynamic>> listenTyping(String roomId) {
    return _globalEventController.stream
        .where((event) => event.channelName == 'chat.$roomId')
        .where((event) => event.eventName == 'UserTyping' || event.eventName == 'App\\Events\\UserTyping')
        .map((event) {
          try {
            final data = jsonDecode(event.data);
            return {
              'user_id': data['user_id']?.toString() ?? '',
              'is_typing': data['is_typing'] == true,
            };
          } catch (_) {}
          return {'user_id': '', 'is_typing': false};
        });
  }

  Stream<Map<String, dynamic>> listenReadReceipt(String roomId) {
    return _globalEventController.stream
        .where((event) => event.channelName == 'chat.$roomId')
        .where((event) => event.eventName == 'MessageRead' || event.eventName == 'App\\Events\\MessageRead')
        .map((event) {
          try {
            final data = jsonDecode(event.data);
            return {
              'room_id': data['room_id']?.toString() ?? '',
              'user_id': data['user_id']?.toString() ?? '',
            };
          } catch (_) {}
          return {'room_id': '', 'user_id': ''};
        });
  }

  // === API METHODS ===

  Future<void> toggleArchive(String roomId, bool archive) async {
    try {
      await _dio.post('/api/rooms/archive', data: {
        'room_id': roomId,
        'is_archived': archive ? 1 : 0,
      });
    } catch (e) { print('Archive Error: $e'); }
  }

  Future<void> deleteRoom(String roomId, String type) async {
    try {
      await _dio.post('/api/rooms/delete', data: {
        'room_id': roomId,
        'type': type, // 'me' atau 'everyone'
      });
    } catch (e) { print('DeleteRoom Error: $e'); }
  }

  Future<void> togglePin(String roomId, bool pin) async {
    try {
      await _dio.post('/api/rooms/pin', data: {
        'room_id': roomId,
        'is_pinned': pin ? 1 : 0,
      });
    } catch (e) { print('Pin Error: $e'); }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    try {
      await _dio.post('/api/user/fcm-token', data: {'fcm_token': fcmToken});
    } catch (e) { print('FCM Token Update Error: $e'); }
  }

  Future<void> leaveRoom(String roomId) async {
    try {
      final channelName = 'chat.$roomId';
      await _pusher.unsubscribe(channelName: channelName);
      _subscribedChannels.remove(channelName);
      print('[Pusher] Unsubscribed from $channelName');
    } catch (_) {}
  }

  Future<void> markAsRead(String roomId) async {
    try {
      await _dio.post('/api/messages/mark-as-read', data: {'room_id': roomId});
    } catch (e) { print('MarkAsRead Error: $e'); }
  }

  Future<void> sendMessage({required String roomId, required String senderId, required String text}) async {
    try {
      await _dio.post('/api/messages', data: {
        'room_id': roomId, 'sender_id': senderId, 'text': text, 'type': 'text',
      });
    } catch (e) { throw Exception('Gagal kirim pesan'); }
  }

  Future<void> sendImage({required String roomId, required String senderId, required String filePath}) async {
    try {
      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        'room_id': roomId, 'sender_id': senderId, 'type': 'image', 'text': '[Gambar]',
        'image': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      await _dio.post('/api/messages', data: formData, options: Options(contentType: 'multipart/form-data'));
    } catch (e) { throw Exception('Gagal kirim gambar'); }
  }

  Future<void> sendTyping(String roomId, bool isTyping) async {
    try { await _dio.post('/api/messages/typing', data: {'room_id': roomId, 'is_typing': isTyping}); } catch (_) {}
  }

  Future<List<MessageModel>> loadMessages(String roomId) async {
    try {
      final response = await _dio.get('/api/messages/$roomId');
      dynamic rawData = response.data;
      if (rawData is Map && rawData.containsKey('data')) rawData = rawData['data'];
      if (rawData is List) return rawData.map((m) => MessageModel.fromMap(m, m['id'].toString())).toList();
      return [];
    } catch (e) { return []; }
  }

  Future<List<UserModel>> getUsers(String currentUid) async {
    try {
      final response = await _dio.get('/api/users');
      dynamic rawData = response.data;
      if (rawData is Map && rawData.containsKey('data')) rawData = rawData['data'];
      if (rawData is List) {
        return rawData.map((u) => UserModel.fromMap(u))
            .where((u) => u.uid.toString() != currentUid.toString()).toList();
      }
      return [];
    } catch (e) { return []; }
  }
}