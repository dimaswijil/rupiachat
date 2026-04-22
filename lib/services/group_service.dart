import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../models/group_model.dart';
import '../main.dart';

class GroupService {
  static final GroupService _instance = GroupService._internal();
  factory GroupService() => _instance;

  static const _baseUrl = 'http://192.168.112.18:8000';

  final _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  GroupService._internal() {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          debugPrint('[GroupService] 401 Unauthenticated — auto logout');
          await _handleUnauthorized();
        }
        return handler.next(error);
      },
    ));
  }

  final _pusher = PusherChannelsFlutter.getInstance();

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

  // ── DAFTAR SEMUA GRUP ──────────────────────────────────────
  Future<List<GroupModel>> getGroups() async {
    try {
      final token = _dio.options.headers['Authorization'];
      if (token == null || token.toString() == 'Bearer ' || token.toString().isEmpty) {
        debugPrint('GetGroups: No valid token found, skipping request.');
        return [];
      }

      final response = await _dio.get('/api/groups');
      dynamic rawData = response.data;
      if (rawData is Map && rawData.containsKey('data')) {
        rawData = rawData['data'];
      }
      if (rawData is List) {
        return rawData.map((g) => GroupModel.fromMap(g)).toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('GetGroups DioError [${e.response?.statusCode}]: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('GetGroups Error: $e');
      return [];
    }
  }

  // ── BUAT GRUP BARU ────────────────────────────────────────
  Future<GroupModel?> createGroup({
    required String name,
    String? description,
    required List<String> memberIds,
  }) async {
    try {
      final response = await _dio.post('/api/groups', data: {
        'name': name,
        'description': description,
        'member_ids': memberIds.map((id) => int.parse(id)).toList(),
      });
      if (response.data['data'] != null) {
        return GroupModel.fromMap(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('CreateGroup Error: $e');
      return null;
    }
  }

  // ── DETAIL GRUP ───────────────────────────────────────────
  Future<GroupModel?> getGroupDetail(String groupId) async {
    try {
      final response = await _dio.get('/api/groups/$groupId');
      if (response.data['data'] != null) {
        return GroupModel.fromMap(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('GetGroupDetail Error: $e');
      return null;
    }
  }

  // ── LOAD PESAN GRUP ───────────────────────────────────────
  Future<List<GroupMessageModel>> loadMessages(String groupId) async {
    try {
      final response = await _dio.get('/api/groups/$groupId/messages');
      dynamic rawData = response.data;
      if (rawData is Map && rawData.containsKey('data')) {
        rawData = rawData['data'];
      }
      if (rawData is List) {
        return rawData.map((m) => GroupMessageModel.fromMap(m)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('LoadGroupMessages Error: $e');
      return [];
    }
  }

  // ── KIRIM PESAN KE GRUP ───────────────────────────────────
  Future<void> sendMessage({
    required String groupId,
    required String text,
  }) async {
    try {
      await _dio.post('/api/groups/$groupId/messages', data: {
        'text': text,
        'type': 'text',
      });
    } catch (e) {
      debugPrint('SendGroupMessage Error: $e');
      throw Exception('Gagal kirim pesan grup');
    }
  }

  // ── KIRIM GAMBAR KE GRUP ──────────────────────────────────
  Future<void> sendImage({
    required String groupId,
    required String filePath,
  }) async {
    try {
      String fileName = filePath.split('/').last;
      FormData formData = FormData.fromMap({
        'type': 'image',
        'text': '[Gambar]',
        'image': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      await _dio.post(
        '/api/groups/$groupId/messages',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
    } catch (e) {
      debugPrint('SendGroupImage Error: $e');
      throw Exception('Gagal kirim gambar');
    }
  }

  // ── LISTEN REALTIME PESAN GRUP ────────────────────────────
  Stream<GroupMessageModel> listenMessages(String groupId) {
    final controller = StreamController<GroupMessageModel>();
    _pusher.subscribe(
      channelName: 'group.$groupId',
      onEvent: (event) {
        if (event.eventName == 'GroupMessageSent' ||
            event.eventName == 'App\\Events\\GroupMessageSent') {
          try {
            final data = jsonDecode(event.data);
            if (data['message'] != null) {
              final message = GroupMessageModel.fromMap(data['message']);
              if (!controller.isClosed) {
                controller.add(message);
              }
            }
          } catch (e) {
            debugPrint('Pusher Group Parse Error: $e');
          }
        }
      },
    );

    controller.onCancel = () {
      _pusher.unsubscribe(channelName: 'group.$groupId');
      controller.close();
    };

    return controller.stream;
  }

  // ── TAMBAH MEMBER ─────────────────────────────────────────
  Future<bool> addMembers(String groupId, List<String> memberIds) async {
    try {
      await _dio.post('/api/groups/$groupId/members', data: {
        'member_ids': memberIds.map((id) => int.parse(id)).toList(),
      });
      return true;
    } catch (e) {
      debugPrint('AddMembers Error: $e');
      return false;
    }
  }

  // ── KELUAR GRUP ───────────────────────────────────────────
  Future<bool> leaveGroup(String groupId) async {
    try {
      await _dio.post('/api/groups/$groupId/leave');
      return true;
    } catch (e) {
      debugPrint('LeaveGroup Error: $e');
      return false;
    }
  }

  // ── HAPUS MEMBER ──────────────────────────────────────────
  Future<bool> removeMember(String groupId, String userId) async {
    try {
      await _dio.delete('/api/groups/$groupId/members/$userId');
      return true;
    } catch (e) {
      debugPrint('RemoveMember Error: $e');
      return false;
    }
  }

  // ── UPDATE NAMA & DESKRIPSI GRUP ──────────────────────────
  Future<bool> updateGroup(String groupId,
      {String? name, String? description}) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      // Include description key when provided so backend can clear it (null = clear)
      if (description != null) {
        // Empty string → send null to nullify description in DB
        data['description'] = description.isEmpty ? null : description;
      }
      await _dio.put('/api/groups/$groupId', data: data);
      return true;
    } catch (e) {
      debugPrint('UpdateGroup Error: $e');
      return false;
    }
  }

  // ── UPDATE FOTO GRUP ──────────────────────────────────────
  Future<String?> updatePhoto(String groupId, String filePath) async {
    try {
      String fileName = filePath.split('/').last;
      FormData formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await _dio.post(
        '/api/groups/$groupId/photo',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data['photo_url'];
    } catch (e) {
      debugPrint('UpdateGroupPhoto Error: $e');
      return null;
    }
  }

  // ── PIN / UNPIN GRUP ──────────────────────────────────────
  Future<bool> pinGroup(String groupId, bool isPinned) async {
    try {
      await _dio.post('/api/groups/$groupId/pin', data: {
        'is_pinned': isPinned,
      });
      return true;
    } catch (e) {
      debugPrint('PinGroup Error: $e');
      return false;
    }
  }
}
