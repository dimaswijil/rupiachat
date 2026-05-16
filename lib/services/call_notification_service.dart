import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../main.dart';
import '../models/user_model.dart';
import '../screens/call/incoming_call_screen.dart';
import '../screens/chat/chat_room_screen.dart';
import '../screens/group/group_chat_screen.dart';
import '../services/chat_service.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

/// Service yang menangani SEMUA FCM messages:
/// - Panggilan masuk (incoming_call, incoming_group_call, call_signal)
/// - Pesan chat masuk (chat_message) → heads-up + navigate saat di-tap
/// - Pesan grup masuk (group_message) → heads-up + navigate saat di-tap
class CallNotificationService {
  static final CallNotificationService _instance = CallNotificationService._();
  factory CallNotificationService() => _instance;
  CallNotificationService._();

  bool _initialized = false;

  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  /// Channel ID ini HARUS SAMA dengan yang ada di AndroidManifest.xml
  /// (com.google.firebase.messaging.default_notification_channel_id)
  static const String _channelId = 'rupiachat_messages';
  static const String _channelName = 'Pesan RupiaChat';
  static const String _channelDesc = 'Notifikasi pesan masuk dari RupiaChat';

  // ══════════════════════════════════════════════════════════
  // INISIALISASI
  // ══════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // ── Step 1: Buat Notification Channel di Android ──
    // Channel ini WAJIB ada sebelum notifikasi bisa muncul (Android 8+).
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,       // Paling tinggi → heads-up popup
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // ── Step 2: Init Local Notifications Plugin ──
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Setting untuk iOS
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotif.initialize(
      initSettings,
      // Callback saat user TAP notifikasi lokal (foreground notification)
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final data = Map<String, dynamic>.from(jsonDecode(response.payload!));
            _handleNotificationTap(data);
          } catch (e) {
            if (kDebugMode) debugPrint('[Notif] Payload parse error: $e');
          }
        }
      },
    );

    // ── Step 3: Minta izin notifikasi (Android 13+) ──
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Juga minta via Firebase (untuk iOS)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ── Step 4: Foreground Presentation (iOS) ──
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // ══════════════════════════════════════════════════════════
    // FCM LISTENERS
    // ══════════════════════════════════════════════════════════

    // 1. FOREGROUND — app sedang terbuka
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 2. BACKGROUND — user tap notif, app sudah di memory
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _handleNotificationTap(msg.data);
    });

    // 3. TERMINATED — user tap notif, app belum jalan
    final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMsg != null) {
      // Delay agar navigator sudah ready setelah app startup
      Future.delayed(const Duration(milliseconds: 1000), () {
        _handleNotificationTap(initialMsg.data);
      });
    }

    // 4. CALLKIT LISTENER (Penting untuk notif panggilan layar penuh)
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      final body = event.body;
      
      switch (event.event) {
        case Event.actionCallAccept:
          if (body['extra'] != null) {
            final data = Map<String, dynamic>.from(body['extra']);
            // Arahkan otomatis ke layar panggilan saat di-accept!
            Future.delayed(const Duration(seconds: 1), () {
              if (data['type'] == 'incoming_group_call') {
                 _showIncomingCall(
                  callerName: data['caller_name'] ?? 'Unknown',
                  callerId: data['caller_id'] ?? '',
                  channelName: data['channel_name'] ?? '',
                  callType: data['call_type'] ?? 'voice',
                  callerPhoto: data['caller_photo'],
                  isGroupCall: true,
                  groupId: data['group_id'],
                  groupName: data['group_name'],
                );
              } else {
                 _showIncomingCall(
                  callerName: data['caller_name'] ?? 'Unknown',
                  callerId: data['caller_id'] ?? '',
                  channelName: data['channel_name'] ?? '',
                  callType: data['call_type'] ?? 'voice',
                  callerPhoto: data['caller_photo'],
                );
              }
            });
          }
          break;
        case Event.actionCallDecline:
          if (body['extra'] != null) {
             // Jika dibutuhkan, bisa kirim signal 'decline' ke backend dari sini
             final data = Map<String, dynamic>.from(body['extra']);
             debugPrint('Panggilan ditolak lewat CallKit: ${data['channel_name']}');
             _handleCallDeclineFromCallKit(data);
          }
          break;
        case Event.actionCallEnded:
        case Event.actionCallTimeout:
           // do nothing
           break;
        default:
          break;
      }
    });

    if (kDebugMode) debugPrint('[Notif] ✅ Service initialized');
  }

  // Handle ketika decline dari native UI
  void _handleCallDeclineFromCallKit(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;
      
      final chatService = ChatService();
      chatService.setToken(token);

      await chatService.sendCallSignal(
        receiverId: data['caller_id'] ?? '',
        channelName: data['channel_name'] ?? '',
        signalType: 'decline',
      );

      await chatService.saveCallLog(
        receiverId: data['caller_id'] ?? '',
        channelName: data['channel_name'] ?? '',
        type: data['call_type'] ?? 'voice',
        status: 'declined',
        duration: 0,
      );
    } catch (e) {
      debugPrint('[IncomingCall] Error decline dari callkit: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  // FOREGROUND HANDLER
  // ══════════════════════════════════════════════════════════

  /// Saat app sedang terbuka dan FCM masuk.
  /// Firebase TIDAK menampilkan notifikasi di system tray pada foreground,
  /// jadi kita tampilkan sendiri via flutter_local_notifications.
  void _onForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';

    if (kDebugMode) {
      debugPrint('[Notif] 📨 Foreground message: type=$type');
      debugPrint('[Notif] data=$data');
      debugPrint('[Notif] notification=${message.notification?.title}');
    }

    switch (type) {
      case 'incoming_call':
        _showIncomingCall(
          callerName: data['caller_name'] ?? 'Unknown',
          callerId: data['caller_id'] ?? '',
          channelName: data['channel_name'] ?? '',
          callType: data['call_type'] ?? 'voice',
          callerPhoto: data['caller_photo'],
        );
        break;

      case 'incoming_group_call':
        _showIncomingCall(
          callerName: data['caller_name'] ?? 'Unknown',
          callerId: data['caller_id'] ?? '',
          channelName: data['channel_name'] ?? '',
          callType: data['call_type'] ?? 'voice',
          callerPhoto: data['caller_photo'],
          isGroupCall: true,
          groupId: data['group_id'],
          groupName: data['group_name'],
        );
        break;

      case 'call_signal':
        _handleCallSignal(data);
        break;

      case 'chat_message':
      case 'group_message':
        _showHeadsUpNotification(message);
        break;

      default:
        // Kalau ada notifikasi FCM tapi tanpa type yang dikenal,
        // tetap tampilkan
        if (message.notification != null) {
          _showHeadsUpNotification(message);
        }
        break;
    }
  }

  // ══════════════════════════════════════════════════════════
  // HEADS-UP NOTIFICATION (Popup dari atas layar)
  // ══════════════════════════════════════════════════════════

  /// Menampilkan notifikasi popup di atas layar saat foreground.
  /// Persis seperti WhatsApp — muncul sebagai banner di notification center.
  void _showHeadsUpNotification(RemoteMessage message) async {
    // Ambil title & body dari notification block ATAU dari data
    final notification = message.notification;
    final data = message.data;

    String title = notification?.title ?? data['sender_name'] ?? 'RupiaChat';
    String body = notification?.body ?? data['text'] ?? 'Pesan baru';

    // Untuk grup, buat format: "NamaGrup - NamaPengirim"
    if (data['type'] == 'group_message' && notification == null) {
      final groupName = data['group_name'] ?? 'Grup';
      final senderName = data['sender_name'] ?? '';
      title = '$groupName - $senderName';
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      // Ini yang bikin notifikasi MUNCUL sebagai popup heads-up
      fullScreenIntent: false,
      category: AndroidNotificationCategory.message,
    );

    const NotificationDetails notifDetails =
        NotificationDetails(android: androidDetails);

    // Gunakan hashCode unik agar setiap pesan punya notif terpisah
    final int notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotif.show(
      notifId,
      title,
      body,
      notifDetails,
      payload: jsonEncode(data),
    );

    if (kDebugMode) debugPrint('[Notif] 🔔 Heads-up shown: $title - $body');
  }

  // ══════════════════════════════════════════════════════════
  // TAP NOTIFICATION → Navigate ke layar yang benar
  // ══════════════════════════════════════════════════════════

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] ?? '';

    if (kDebugMode) debugPrint('[Notif] 👆 Tapped notification: type=$type');

    switch (type) {
      case 'incoming_call':
        _showIncomingCall(
          callerName: data['caller_name'] ?? 'Unknown',
          callerId: data['caller_id'] ?? '',
          channelName: data['channel_name'] ?? '',
          callType: data['call_type'] ?? 'voice',
          callerPhoto: data['caller_photo'],
        );
        break;

      case 'incoming_group_call':
        _showIncomingCall(
          callerName: data['caller_name'] ?? 'Unknown',
          callerId: data['caller_id'] ?? '',
          channelName: data['channel_name'] ?? '',
          callType: data['call_type'] ?? 'voice',
          callerPhoto: data['caller_photo'],
          isGroupCall: true,
          groupId: data['group_id'],
          groupName: data['group_name'],
        );
        break;

      case 'call_signal':
        _handleCallSignal(data);
        break;

      case 'chat_message':
        _openChatRoom(data);
        break;

      case 'group_message':
        _openGroupChat(data);
        break;
    }
  }

  // ══════════════════════════════════════════════════════════
  // PANGGILAN MASUK
  // ══════════════════════════════════════════════════════════

  void _showIncomingCall({
    required String callerName,
    required String callerId,
    required String channelName,
    required String callType,
    String? callerPhoto,
    bool isGroupCall = false,
    String? groupId,
    String? groupName,
  }) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      if (kDebugMode) debugPrint('[Notif] Navigator not ready');
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callerName: callerName,
          callerId: callerId,
          channelName: channelName,
          callType: callType,
          callerPhoto: (callerPhoto != null && callerPhoto.isNotEmpty)
              ? callerPhoto
              : null,
          isGroupCall: isGroupCall,
          groupId: groupId,
          groupName: groupName,
        ),
      ),
    );
  }

  void _handleCallSignal(Map<String, dynamic> data) {
    final signalType = data['signal_type'];
    if (kDebugMode) debugPrint('[Notif] Signal: $signalType');

    if (signalType == 'cancel' || signalType == 'end') {
      final navigator = navigatorKey.currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  // CHAT MESSAGE TAP → Buka Chat Room
  // ══════════════════════════════════════════════════════════

  void _openChatRoom(Map<String, dynamic> data) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final senderId = data['sender_id'] ?? '';
    final senderName = data['sender_name'] ?? 'Unknown';
    final senderPhoto = data['sender_photo'] ?? '';
    final senderEmail = data['sender_email'] ?? '';
    final roomId = data['room_id'] ?? '';

    if (senderId.isEmpty || roomId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final currentUid = prefs.getString('user_id') ?? '';
    final authToken = prefs.getString('auth_token') ?? '';

    if (currentUid.isEmpty) return;

    final otherUser = UserModel(
      uid: senderId,
      name: senderName,
      email: senderEmail,
      photoUrl: senderPhoto.isNotEmpty ? senderPhoto : null,
    );

    final chatService = ChatService();
    chatService.setToken(authToken);

    if (kDebugMode) debugPrint('[Notif] Opening chat: $roomId with $senderName');

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          otherUser: otherUser,
          roomId: roomId,
          currentUid: currentUid,
          chatService: chatService,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // GROUP MESSAGE TAP → Buka Group Chat
  // ══════════════════════════════════════════════════════════

  void _openGroupChat(Map<String, dynamic> data) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final groupId = data['group_id'] ?? '';
    final groupName = data['group_name'] ?? 'Grup';
    final groupPhoto = data['group_photo'];

    if (groupId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final currentUid = prefs.getString('user_id') ?? '';

    if (currentUid.isEmpty) return;

    if (kDebugMode) debugPrint('[Notif] Opening group: $groupId ($groupName)');

    navigator.push(
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(
          groupId: groupId,
          groupName: groupName,
          groupPhoto: (groupPhoto != null && groupPhoto.isNotEmpty) ? groupPhoto : null,
          currentUid: currentUid,
        ),
      ),
    );
  }
}
