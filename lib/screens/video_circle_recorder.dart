import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCircleRecorder extends StatefulWidget {
  const VideoCircleRecorder({super.key});

  @override
  State<VideoCircleRecorder> createState() => _VideoCircleRecorderState();
}

class _VideoCircleRecorderState extends State<VideoCircleRecorder> {
  CameraController? _controller;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _timer;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndInit();
  }

  Future<void> _checkPermissionsAndInit() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (cameraStatus.isGranted && micStatus.isGranted) {
      _initCamera();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Необходимы разрешения на камеру и микрофон')),
        );
      }
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    
    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  void _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _isRecording) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) {
          setState(() => _recordDuration++);
          if (_recordDuration >= 60) _stopRecording(); 
        }
      });
    } catch (e) {
      debugPrint("Start recording error: $e");
    }
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    _timer?.cancel();
    
    try {
      final XFile file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      if (mounted) Navigator.pop(context, File(file.path));
    } catch (e) {
      debugPrint("Stop recording error: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady || _controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('Видео-сообщение', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _isRecording ? Colors.red : Colors.white, width: 4),
                ),
                child: ClipOval(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isRecording)
              Text('00:${_recordDuration.toString().padLeft(2, '0')}', 
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                children: [
                  GestureDetector(
                    onLongPress: _startRecording,
                    onLongPressUp: _stopRecording,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)
                        ]
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.videocam,
                        color: _isRecording ? Colors.white : Colors.blueGrey[900],
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Удерживайте для записи', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ОТМЕНА', style: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
