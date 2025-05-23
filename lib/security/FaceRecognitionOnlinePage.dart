// FaceRecognitionOnlinePage.dart
import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FaceRecognitionOnlinePage extends StatefulWidget {
  const FaceRecognitionOnlinePage({super.key});

  @override
  State<FaceRecognitionOnlinePage> createState() =>
      _FaceRecognitionOnlinePageState();
}

class _FaceRecognitionOnlinePageState extends State<FaceRecognitionOnlinePage> {
  CameraController? _controller;
  late Timer _timer;
  String _result = '';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

Future<void> _initCamera() async {
  try {
    final cameras = await availableCameras();
    print("✅ Cameras found: ${cameras.length}");
    for (final cam in cameras) {
      print("Camera: ${cam.name} (${cam.lensDirection})");
    }

    if (cameras.isEmpty) {
      setState(() {
        _result = 'لا توجد كاميرات متاحة';
      });
      return;
    }

    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    await _controller!.initialize();
    print("✅ Camera initialized");

    setState(() {});

    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) => _processFrame());
  } catch (e) {
    print("❌ Camera init error: $e");
    setState(() {
      _result = 'فشل في فتح الكاميرا';
    });
  }
}


  Future<void> _processFrame() async {
    if (!_controller!.value.isInitialized || _controller!.value.isTakingPicture) {
      return;
    }

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('http://192.168.1.101:5050/recognize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _result = decoded['faces'].join(', ');
        });
      } else {
        setState(() {
          _result = 'خطأ في التعرف';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'فشل في المعالجة';
      });
    }
  }

  @override
  void dispose() {
    if (_timer.isActive) _timer.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Recognition Online')),
      body: Column(
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            )
          else
            const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Text('النتيجة: $_result', style: const TextStyle(fontSize: 20))
        ],
      ),
    );
  }
}
