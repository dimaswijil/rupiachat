import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class CallApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Future<Map<String, String>> _getHeaders() async {
    final authToken = await AuthService().currentToken;
    return {
      'Authorization': 'Bearer ${authToken ?? ''}',
      'Accept': 'application/json',
    };
  }

  /// Request Agora Token untuk channel panggilan tertentu
  Future<String> fetchAgoraToken(String channelName) async {
    final headers = await _getHeaders();
    final response = await _dio.post(
      '/api/agora/token',
      data: {
        'channel_name': channelName,
        'uid': '0',
      },
      options: Options(headers: headers),
    );
    return response.data['token'] ?? '';
  }

  /// Kirim FCM panggilan ke penerima (hanya dijalankan oleh pemanggil)
  Future<void> sendCallFcm({
    required String receiverId,
    required String channelName,
    required bool isVideoCall,
  }) async {
    final headers = await _getHeaders();
    await _dio.post(
      '/api/agora/call',
      data: {
        'receiver_id': receiverId,
        'channel_name': channelName,
        'call_type': isVideoCall ? 'video' : 'voice',
      },
      options: Options(headers: headers),
    );
  }

  /// Kirim FCM panggilan grup ke semua anggota grup
  Future<void> sendGroupCallFcm({
    required String groupId,
    required String channelName,
    required bool isVideoCall,
    required String groupName,
  }) async {
    final headers = await _getHeaders();
    await _dio.post(
      '/api/agora/group-call',
      data: {
        'group_id': groupId,
        'channel_name': channelName,
        'call_type': isVideoCall ? 'video' : 'voice',
        'group_name': groupName,
      },
      options: Options(headers: headers),
    );
  }

  /// Kirim sinyal panggilan (cancel, decline, dsb.) ke penerima
  Future<void> sendCallSignal({
    required String targetId,
    required String channelName,
    required String signalType,
  }) async {
    final headers = await _getHeaders();
    await _dio.post(
      '/api/agora/signal',
      data: {
        'target_id': targetId,
        'channel_name': channelName,
        'signal_type': signalType,
      },
      options: Options(headers: headers),
    );
  }

  /// Simpan log panggilan (durasi, jenis, status) ke database
  Future<void> saveCallLog({
    required String otherUserId,
    required String channelName,
    required bool isVideoMode,
    required bool remoteUserJoined,
    required int durationSeconds,
    String? status, // opsional: 'declined', 'missed', 'answered'
  }) async {
    final headers = await _getHeaders();
    final resolvedStatus = status ?? (remoteUserJoined ? 'answered' : 'missed');
    await _dio.post(
      '/api/call-logs',
      data: {
        'receiver_id': otherUserId,
        'channel_name': channelName,
        'type': isVideoMode ? 'video' : 'voice',
        'status': resolvedStatus,
        'duration': durationSeconds,
      },
      options: Options(headers: headers),
    );
  }

  /// Request Agora Token untuk panggilan grup
  Future<String> fetchGroupAgoraToken({
    required String channelId,
    required String currentUid,
  }) async {
    final headers = await _getHeaders();
    final response = await _dio.post(
      '/api/agora/token',
      data: {
        'channel_name': channelId,
        'uid': currentUid,
      },
      options: Options(headers: headers),
    );
    return response.data['token'] ?? '';
  }

  /// Simpan log panggilan grup ke database
  Future<void> saveGroupCallLog({
    required String groupId,
    required String groupName,
    required String channelId,
    required bool isVideoMode,
    required bool hasParticipants,
    required int durationSeconds,
  }) async {
    final headers = await _getHeaders();
    await _dio.post(
      '/api/call-logs',
      data: {
        'group_id': groupId,
        'group_name': groupName,
        'channel_name': channelId,
        'type': isVideoMode ? 'video' : 'voice',
        'status': hasParticipants ? 'answered' : 'missed',
        'duration': durationSeconds,
      },
      options: Options(headers: headers),
    );
  }

  /// Ambil daftar seluruh log riwayat panggilan dari server
  Future<List<Map<String, dynamic>>> fetchCallLogs() async {
    final headers = await _getHeaders();
    final response = await _dio.get(
      '/api/call-logs',
      options: Options(headers: headers),
    );
    final rawData = response.data;
    List<Map<String, dynamic>> logs = [];
    if (rawData is Map && rawData.containsKey('data')) {
      final dataList = rawData['data'];
      if (dataList is List) {
        for (var item in dataList) {
          if (item is Map) {
            logs.add(Map<String, dynamic>.from(item));
          }
        }
      }
    }
    return logs;
  }
}
