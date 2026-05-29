import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import '../contacts/contact_info_screen.dart';
import '../group/group_info_screen.dart';
import 'call_screen.dart';
import 'group_call_screen.dart';
import 'controllers/call_history_controller.dart';
import 'widgets/history/history_search_bar.dart';
import 'widgets/history/history_empty_state.dart';
import 'widgets/history/history_call_tile.dart';
import '../../widgets/premium_lock_overlay.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen>
    with AutomaticKeepAliveClientMixin {
  late final CallHistoryController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = CallHistoryController();
    _controller.addListener(_onControllerChanged);
    _controller.loadCallLogs();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Tap on a call tile → repeat the call (voice or video)
  void _onCallTileTap(Map<String, dynamic> call) async {
    final isGroup = call['is_group'] == true;
    final type = call['type']?.toString() ?? 'voice';
    final isVideo = type == 'video';

    if (isGroup) {
      final groupId = call['group_id']?.toString() ?? '';
      final groupName = call['group_name']?.toString() ?? 'Grup';
      if (groupId.isEmpty) return;
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => GroupCallScreen(
          channelName: groupId,
          groupName: groupName,
          isVideoCall: isVideo,
        ),
      ));
    } else {
      final uid = await AuthService().currentUid ?? '';
      final otherUserId = call['other_user_id']?.toString() ?? '';
      final otherUserName = call['other_user_name']?.toString() ?? 'Unknown';
      if (otherUserId.isEmpty) return;
      if (!mounted) return;
      // FIXED Bug #11: Generate channel name BARU setiap re-call
      final sortedIds = [uid, otherUserId]..sort();
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final channelName = 'call_${sortedIds[0]}_${sortedIds[1]}_$timestamp';
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CallScreen(
          channelName: channelName,
          otherUserName: otherUserName,
          otherUserId: otherUserId,
          otherUserPhoto: call['other_user_photo']?.toString(),
          isVideoCall: isVideo,
        ),
      ));
    }
  }

  /// Tap on info icon → navigate to contact/group info
  void _onInfoTap(Map<String, dynamic> call) async {
    final isGroup = call['is_group'] == true;
    final currentUid = await AuthService().currentUid ?? '';

    if (isGroup) {
      final groupId = call['group_id']?.toString() ?? '';
      if (groupId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Info grup tidak tersedia')),
          );
        }
        return;
      }
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => GroupInfoScreen(
            groupId: groupId,
            currentUid: currentUid,
            showCallHistory: true,
          ),
        ));
      }
    } else {
      final otherUser = UserModel(
        uid: call['other_user_id']?.toString() ?? '',
        name: call['other_user_name']?.toString() ?? 'Unknown',
        email: call['other_user_email']?.toString() ?? '',
        phone: call['other_user_phone']?.toString(),
        photoUrl: call['other_user_photo']?.toString(),
      );
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ContactInfoScreen(
            user: otherUser,
            roomId: '',
            currentUid: currentUid,
            showCallHistory: true,
          ),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _controller.filteredCalls;

    return Scaffold(
      backgroundColor: isDark ? RupiaColors.bgDark : RupiaColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF0D2B6B), RupiaColors.primary],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Panggilan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
            elevation: 0,
            automaticallyImplyLeading: false,
          ),
        ),
      ),
      body: PremiumLockOverlay(
        featureSlug: 'voice_call', // Any call feature unlocks this (or VIP)
        title: 'Fitur Panggilan Terkunci',
        message: 'Tingkatkan ke VIP Member untuk membuka fitur Panggilan Suara & Video tanpa batas, serta akses semua fitur premium lainnya.',
        child: Column(
          children: [
            // ── Search bar ──
            HistorySearchBar(
              isDark: isDark,
              onChanged: _controller.updateSearchQuery,
            ),

            // ── Call List ──
            Expanded(
              child: Container(
                color: isDark ? RupiaColors.bgDark : RupiaColors.bg,
                child: _controller.loading
                    ? Center(child: CircularProgressIndicator(color: RupiaColors.primary))
                    : filtered.isEmpty
                        ? HistoryEmptyState(isDark: isDark)
                        : RefreshIndicator(
                            onRefresh: _controller.loadCallLogs,
                            color: RupiaColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) => Column(
                                children: [
                                  HistoryCallTile(
                                    call: filtered[index],
                                    isDark: isDark,
                                    onTap: () => _onCallTileTap(filtered[index]),
                                    onInfoTap: () => _onInfoTap(filtered[index]),
                                  ),
                                  Divider(
                                    indent: 72,
                                    height: 1,
                                    thickness: 0.5,
                                    color: isDark ? Colors.white10 : Colors.black12,
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
