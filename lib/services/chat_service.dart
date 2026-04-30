import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../config/api_config.dart';
import '../main.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  static const _baseUrl = ApiConfig.baseUrl;

  final _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  ChatService._internal() {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          debugPrint('[ChatService] 401 Unauthenticated — auto logout');
          await _handleUnauthorized();
        }
        return handler.next(error);
      },
    ));
  }

  // === PUSHER ULTIMATE SINGLETON ===
  static final _pusher = PusherChannelsFlutter.getInstance();
  static final StreamController<PusherEvent> _globalEventController = StreamController<PusherEvent>.broadcast();
  static bool _pusherInitialized = false;
  static Completer<void>? _initCompleter; // ← Mencegah init ganda
  static final Set<String> _subscribedChannels = {};
  static String _lastConnectionState = '';
  static int _errorCount = 0; // ← Membatasi spam log error

  static Future<void> initPusher() async {
    // Jika sudah selesai init, cukup pastikan tetap connected
    if (_pusherInitialized) {
      try {
        await _pusher.connect();
      } catch (_) {}
      return;
    }

    // Jika sedang proses init (dipanggil dari tempat lain), tunggu saja
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    // Mulai proses init — kunci agar tidak bisa dipanggil ganda
    _initCompleter = Completer<void>();

    try {
      if (kDebugMode) debugPrint('[Pusher] Initializing core pipeline...');
      _errorCount = 0;

      await _pusher.init(
        apiKey: 'fd71e26c996be8a21eef',
        cluster: 'ap1',
        onEvent: (event) {
          _globalEventController.add(event);
        },
        onConnectionStateChange: (state, prev) {
          if (kDebugMode) debugPrint('[Pusher] Connection: $prev -> $state');
          _lastConnectionState = state;

          // Reset error counter saat berhasil connect
          if (state == 'CONNECTED') {
            _errorCount = 0;
          }

          // ✅ KUNCI FIX ANDROID: Saat Pusher berhasil reconnect,
          // subscribe ulang SEMUA channel yang sebelumnya aktif.
          if (state == 'CONNECTED' && _subscribedChannels.isNotEmpty) {
            final channels = Set<String>.from(_subscribedChannels);
            for (final ch in channels) {
              try {
                _pusher.subscribe(channelName: ch);
                if (kDebugMode) debugPrint('[Pusher] Re-subscribed to $ch after reconnect');
              } catch (e) {
                debugPrint('[Pusher] Re-subscribe error for $ch: $e');
              }
            }
          }
        },
        onError: (msg, code, e) {
          // Batasi log error agar tidak membanjiri console
          _errorCount++;
          if (_errorCount <= 2) {
            debugPrint('[Pusher] Error #$_errorCount: $msg ($code)');
          }
          // Diam-diam setelah 2 error — Pusher sudah auto-reconnect sendiri
        },
      );

      // ── Retry connect dengan exponential backoff ──
      // Library pusher kadang gagal pada connect() pertama di emulator,
      // jadi kita coba beberapa kali dengan jeda yang makin lama.
      bool connected = false;
      for (int attempt = 1; attempt <= 5; attempt++) {
        try {
          await _pusher.connect();
          // Tunggu sebentar untuk cek apakah benar-benar tersambung
          await Future.delayed(Duration(seconds: attempt));
          if (_lastConnectionState == 'CONNECTED') {
            connected = true;
            break;
          }
          debugPrint('[Pusher] Attempt $attempt: state=$_lastConnectionState, retrying...');
        } catch (e) {
          debugPrint('[Pusher] Connect attempt $attempt failed: $e');
        }
        // Tunggu sebelum retry berikutnya (2s, 4s, 8s, 16s, 32s)
        await Future.delayed(Duration(seconds: attempt * 2));
      }

      _pusherInitialized = true;
      if (connected) {
        debugPrint('[Pusher] ✅ Core pipeline ready & CONNECTED');
      } else {
        debugPrint('[Pusher] ⚠️ Initialized but not yet connected — will auto-retry in background');
      }
    } catch (e) {
      debugPrint('[Pusher] Critical Init Error: $e');
    } finally {
      // Selesai init — buka kunci agar caller lain bisa lanjut
      _initCompleter?.complete();
      _initCompleter = null;
    }
  }

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  static bool _isHandlingUnauth = false;
  Future<void> _handleUnauthorized() async {
    if (_isHandlingUnauth) return;
    _isHandlingUnauth = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } finally {
      _isHandlingUnauth = false;
    }
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
      if (kDebugMode) debugPrint('[Pusher] Subscribed to $channelName');
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
            debugPrint('[Pusher] Message Parse Error: $e');
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
      if (kDebugMode) debugPrint('[Pusher] Subscribed to $channelName');
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
    } catch (e) { debugPrint('Archive Error: $e'); }
  }

  Future<void> deleteRoom(String roomId, String type) async {
    try {
      await _dio.post('/api/rooms/delete', data: {
        'room_id': roomId,
        'type': type, // 'me' atau 'everyone'
      });
    } catch (e) { debugPrint('DeleteRoom Error: $e'); }
  }

  Future<void> togglePin(String roomId, bool pin) async {
    try {
      await _dio.post('/api/rooms/pin', data: {
        'room_id': roomId,
        'is_pinned': pin ? 1 : 0,
      });
    } catch (e) { debugPrint('Pin Error: $e'); }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    try {
      await _dio.post('/api/user/fcm-token', data: {'fcm_token': fcmToken});
    } catch (e) { debugPrint('FCM Token Update Error: $e'); }
  }

  Future<void> leaveRoom(String roomId) async {
    try {
      final channelName = 'chat.$roomId';
      await _pusher.unsubscribe(channelName: channelName);
      _subscribedChannels.remove(channelName);
      if (kDebugMode) debugPrint('[Pusher] Unsubscribed from $channelName');
    } catch (_) {}
  }

  Future<void> markAsRead(String roomId) async {
    try {
      await _dio.post('/api/messages/mark-as-read', data: {'room_id': roomId});
    } catch (e) { debugPrint('MarkAsRead Error: $e'); }
  }

  Future<void> sendMessage({required String roomId, required String senderId, required String text, String type = 'text'}) async {
    try {
      await _dio.post('/api/messages', data: {
        'room_id': roomId, 'sender_id': senderId, 'text': text, 'type': type,
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