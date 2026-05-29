import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class VideoCallView extends StatefulWidget {
  final RtcEngine engine;
  final String channelName;
  final int? remoteUid;
  final bool remoteUserJoined;
  final bool cameraOff;
  final bool isRemoteVideoFrozen;
  final int? localUid;
  final bool isFrontCamera;

  const VideoCallView({
    super.key,
    required this.engine,
    required this.channelName,
    required this.remoteUid,
    required this.remoteUserJoined,
    required this.cameraOff,
    required this.isRemoteVideoFrozen,
    required this.isFrontCamera,
    this.localUid,
  });

  @override
  State<VideoCallView> createState() => _VideoCallViewState();
}

class _VideoCallViewState extends State<VideoCallView> {
  final GlobalKey _localVideoKey = GlobalKey();

  // Posisi awal jendela melayang (PiP)
  double _pipTop = 80;
  double _pipRight = 16;

  @override
  Widget build(BuildContext context) {
    // Sebelum remote user bergabung - tampilkan kamera lokal layar penuh
    if (!widget.remoteUserJoined) {
      if (widget.cameraOff) {
        return const SizedBox.shrink();
      }
      return Stack(
        children: [
          Positioned.fill(
            child: AgoraVideoView(
              key: _localVideoKey,
              controller: VideoViewController(
                rtcEngine: widget.engine,
                canvas: VideoCanvas(
                  uid: 0, // local user
                  renderMode: RenderModeType.renderModeHidden,
                  mirrorMode: widget.isFrontCamera
                      ? VideoMirrorModeType.videoMirrorModeEnabled
                      : VideoMirrorModeType.videoMirrorModeDisabled,
                ),
                useFlutterTexture: true,
                useAndroidSurfaceView: false,
              ),
            ),
          ),
        ],
      );
    }

    // Setelah remote user bergabung - tampilkan video remote layar penuh dan kamera lokal PiP melayang
    return Stack(
      children: [
        // Remote video fullscreen
        if (widget.remoteUid != null)
          Positioned.fill(
            child: AgoraVideoView(
              key: ValueKey('agora_remote_${widget.remoteUid}'),
              controller: VideoViewController.remote(
                rtcEngine: widget.engine,
                canvas: VideoCanvas(
                  uid: widget.remoteUid!,
                  renderMode: RenderModeType.renderModeHidden,
                ),
                connection: RtcConnection(
                  channelId: widget.channelName,
                  localUid: widget.localUid,
                ),
                useFlutterTexture: true,
                useAndroidSurfaceView: false,
              ),
            ),
          ),
        
        // Overlay koneksi lemah
        if (widget.isRemoteVideoFrozen)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white70),
                    SizedBox(height: 16),
                    Text('Koneksi lemah...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),

        // PiP: Kamera lokal melayang di pojok layar (Draggable)
        if (!widget.cameraOff)
          Positioned(
            top: _pipTop,
            right: _pipRight,
            child: GestureDetector(
              onPanUpdate: (d) {
                setState(() {
                  _pipTop = (_pipTop + d.delta.dy).clamp(40, MediaQuery.of(context).size.height - 220);
                  _pipRight = (_pipRight - d.delta.dx).clamp(8, MediaQuery.of(context).size.width - 130);
                });
              },
              child: Container(
                width: 110,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white30, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 12)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AgoraVideoView(
                    key: _localVideoKey,
                    controller: VideoViewController(
                      rtcEngine: widget.engine,
                      canvas: VideoCanvas(
                        uid: 0, // local user = uid 0
                        renderMode: RenderModeType.renderModeHidden,
                        mirrorMode: widget.isFrontCamera
                            ? VideoMirrorModeType.videoMirrorModeEnabled
                            : VideoMirrorModeType.videoMirrorModeDisabled,
                      ),
                      useFlutterTexture: true,
                      useAndroidSurfaceView: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
