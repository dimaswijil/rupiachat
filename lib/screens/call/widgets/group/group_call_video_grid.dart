import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class GroupCallVideoGrid extends StatelessWidget {
  final RtcEngine engine;
  final String channelName;
  final Map<int, bool> remoteUsers;
  final bool cameraOff;
  final bool muted;
  final bool engineReady;
  final int? localUid;
  final bool isFrontCamera;
  final Map<String, String> memberNames;

  const GroupCallVideoGrid({
    super.key,
    required this.engine,
    required this.channelName,
    required this.remoteUsers,
    required this.cameraOff,
    required this.muted,
    required this.engineReady,
    required this.isFrontCamera,
    required this.memberNames,
    this.localUid,
  });

  @override
  Widget build(BuildContext context) {
    final participants = remoteUsers.keys.toList();
    final totalParticipants = participants.length + 1; // +1 untuk lokal

    // ── LAYOUT 1: Hanya ada Anda sendiri di dalam room ──
    if (totalParticipants == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: (cameraOff || !engineReady)
                    ? _buildAvatarPlaceholder('Anda')
                    : AgoraVideoView(
                        key: const ValueKey('agora_group_local'),
                        controller: VideoViewController(
                          rtcEngine: engine,
                          canvas: VideoCanvas(
                            uid: 0, // Agora mewajibkan 0 untuk preview local user
                            renderMode: RenderModeType.renderModeHidden,
                            mirrorMode: isFrontCamera
                                ? VideoMirrorModeType.videoMirrorModeEnabled
                                : VideoMirrorModeType.videoMirrorModeDisabled,
                          ),
                          useFlutterTexture: true,
                          useAndroidSurfaceView: false,
                        ),
                      ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                child: _buildLabelOverlay('Anda', muted),
              ),
            ],
          ),
        ),
      );
    }

    // ── LAYOUT 2: Panggilan 1-on-1 (Split Screen: Setengah atas Anda, Setengah bawah Lawan Bicara) ──
    if (totalParticipants == 2) {
      final remoteUid = participants[0];
      final hasVideo = remoteUsers[remoteUid] ?? false;
      final remoteName = memberNames[remoteUid.toString()] ?? 'Peserta 1';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Setengah Atas: Kamera Anda (Anda)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: (cameraOff || !engineReady)
                          ? _buildAvatarPlaceholder('Anda')
                          : AgoraVideoView(
                              key: const ValueKey('agora_group_local'),
                              controller: VideoViewController(
                                rtcEngine: engine,
                                canvas: VideoCanvas(
                                  uid: 0, // Agora mewajibkan 0 untuk preview local user
                                  renderMode: RenderModeType.renderModeHidden,
                                  mirrorMode: isFrontCamera
                                      ? VideoMirrorModeType.videoMirrorModeEnabled
                                      : VideoMirrorModeType.videoMirrorModeDisabled,
                                ),
                                useFlutterTexture: true,
                                useAndroidSurfaceView: false,
                              ),
                            ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: _buildLabelOverlay('Anda', muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Setengah Bawah: Kamera Lawan Bicara (Sesuai nama user di grup)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: (!engineReady)
                          ? _buildAvatarPlaceholder(remoteName)
                          : Stack(
                              children: [
                                Positioned.fill(
                                  child: AgoraVideoView(
                                    key: ValueKey('agora_group_remote_$remoteUid'),
                                    controller: VideoViewController.remote(
                                      rtcEngine: engine,
                                      canvas: VideoCanvas(
                                        uid: remoteUid,
                                        renderMode: RenderModeType.renderModeHidden,
                                      ),
                                      connection: RtcConnection(
                                        channelId: 'group_$channelName',
                                        localUid: localUid,
                                      ),
                                      useFlutterTexture: true,
                                      useAndroidSurfaceView: false,
                                    ),
                                  ),
                                ),
                                if (!hasVideo)
                                  Positioned.fill(
                                    child: _buildAvatarPlaceholder(remoteName),
                                  ),
                              ],
                            ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: _buildLabelOverlay(remoteName, false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── LAYOUT 3: Panggilan Grup (3 Peserta atau Lebih - Grid 2 Kolom Seimbang) ──
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: totalParticipants,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Local User (Anda)
            return _buildVideoTile(
              child: (cameraOff || !engineReady)
                  ? _buildAvatarPlaceholder('Anda')
                  : AgoraVideoView(
                      key: const ValueKey('agora_group_local'),
                      controller: VideoViewController(
                        rtcEngine: engine,
                        canvas: VideoCanvas(
                          uid: 0, // Agora mewajibkan 0 untuk local user
                          renderMode: RenderModeType.renderModeHidden,
                          mirrorMode: isFrontCamera
                              ? VideoMirrorModeType.videoMirrorModeEnabled
                              : VideoMirrorModeType.videoMirrorModeDisabled,
                        ),
                        useFlutterTexture: true,
                        useAndroidSurfaceView: false,
                      ),
                    ),
              label: 'Anda',
              isMuted: muted,
            );
          }

          // Remote Users (Peserta Lain)
          final remoteUid = participants[index - 1];
          final hasVideo = remoteUsers[remoteUid] ?? false;
          final remoteName = memberNames[remoteUid.toString()] ?? 'Peserta $index';

          return _buildVideoTile(
            child: (!engineReady)
                ? _buildAvatarPlaceholder(remoteName)
                : Stack(
                    children: [
                      Positioned.fill(
                        child: AgoraVideoView(
                          key: ValueKey('agora_group_remote_$remoteUid'),
                          controller: VideoViewController.remote(
                            rtcEngine: engine,
                            canvas: VideoCanvas(
                              uid: remoteUid,
                              renderMode: RenderModeType.renderModeHidden,
                            ),
                            connection: RtcConnection(
                              channelId: 'group_$channelName',
                              localUid: localUid,
                            ),
                            useFlutterTexture: true,
                            useAndroidSurfaceView: false,
                          ),
                        ),
                      ),
                      if (!hasVideo)
                        Positioned.fill(
                          child: _buildAvatarPlaceholder(remoteName),
                        ),
                    ],
                  ),
            label: remoteName,
            isMuted: false,
          );
        },
      ),
    );
  }

  Widget _buildVideoTile({
    required Widget child,
    required String label,
    required bool isMuted,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 8,
            bottom: 8,
            child: _buildLabelOverlay(label, isMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelOverlay(String label, bool isMuted, {bool isMini = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMini ? 6 : 8,
        vertical: isMini ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMini ? 10 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isMuted) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.mic_off_rounded,
              color: Colors.redAccent,
              size: isMini ? 11 : 13,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name, {bool isMini = false}) {
    return Container(
      color: const Color(0xFF131926),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isMini ? 40 : 54,
              height: isMini ? 40 : 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMini ? 16 : 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                color: Colors.white60,
                fontSize: isMini ? 11 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
