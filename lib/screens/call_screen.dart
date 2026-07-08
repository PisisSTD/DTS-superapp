import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/signaling_service.dart';

class CallScreen extends StatefulWidget {
  final String? roomId;
  final String? receiverId;
  final bool isVideo;
  final bool isIncoming;

  const CallScreen({
    super.key, 
    this.roomId, 
    this.receiverId, 
    this.isVideo = false, 
    this.isIncoming = false
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final SignalingService _signaling = SignalingService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAndStart();
  }

  Future<void> _initAndStart() async {
    // Проверка разрешений
    final micStatus = await Permission.microphone.request();
    if (widget.isVideo) {
      await Permission.camera.request();
    }

    if (micStatus.isDenied) {
      if (mounted) Navigator.pop(context);
      return;
    }

    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _signaling.onAddRemoteStream = ((stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      }
    });

    _signaling.onCallEnded = () {
      if (mounted) Navigator.pop(context);
    };

    try {
      if (widget.isIncoming) {
        await _signaling.joinRoom(widget.roomId!);
      } else {
        await _signaling.createRoom(widget.receiverId!, widget.isVideo);
      }

      if (mounted) {
        setState(() {
          _localRenderer.srcObject = _signaling.localStream;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка звонка: $e')));
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _signaling.hangUp();
    super.dispose();
  }

  void _toggleMic() {
    setState(() {
      _isMicOn = !_isMicOn;
      _signaling.localStream?.getAudioTracks().forEach((track) {
        track.enabled = _isMicOn;
      });
    });
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
      _signaling.localStream?.getVideoTracks().forEach((track) {
        track.enabled = _isCameraOn;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Удаленное видео (собеседник)
          Positioned.fill(
            child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          ),
          
          // Твое видео (маленькое окно)
          if (widget.isVideo)
            Positioned(
              right: 20,
              top: 50,
              width: 110,
              height: 160,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)]
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),
            ),

          // Кнопки управления
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallButton(
                  icon: _isMicOn ? Icons.mic : Icons.mic_off,
                  color: _isMicOn ? Colors.white24 : Colors.red,
                  onPressed: _toggleMic,
                ),
                _buildCallButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onPressed: () => Navigator.pop(context),
                  size: 35,
                ),
                if (widget.isVideo)
                  _buildCallButton(
                    icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                    color: _isCameraOn ? Colors.white24 : Colors.red,
                    onPressed: _toggleCamera,
                  ),
              ],
            ),
          ),
          
          // Текст статуса, если нет видео
          if (_remoteRenderer.srcObject == null)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 50, backgroundColor: Colors.white10, child: Icon(Icons.person, size: 60, color: Colors.white30)),
                  SizedBox(height: 20),
                  Text('Ожидание подключения...', style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCallButton({required IconData icon, required Color color, required VoidCallback onPressed, double size = 25}) {
    return CircleAvatar(
      backgroundColor: color,
      radius: 30,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size),
        onPressed: onPressed,
      ),
    );
  }
}
