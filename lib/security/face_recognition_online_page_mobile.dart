import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

class FaceRecognitionOnlinePage extends StatefulWidget {
  const FaceRecognitionOnlinePage({super.key});

  @override
  State<FaceRecognitionOnlinePage> createState() =>
      _FaceRecognitionOnlinePageState();
}

class _FaceRecognitionOnlinePageState extends State<FaceRecognitionOnlinePage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  List<Map<String, dynamic>> _detectedFaces = [];
  String _rawJson = '';

  @override
  void initState() {
    super.initState();
    _initMobileCamera();
  }

  Future<void> _initMobileCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _detectedFaces = [
            {'name': 'No camera found'}
          ];
        });
        return;
      }
      _cameraController = CameraController(
          _cameras![0], ResolutionPreset.medium,
          enableAudio: false);
      await _cameraController!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
      _startMobileFrameStream();
    } catch (e) {
      setState(() {
        _detectedFaces = [
          {'name': 'فشل في الوصول إلى الكاميرا'}
        ];
      });
    }
  }

  void _startMobileFrameStream() {
    Future.doWhile(() async {
      if (!mounted || !_isCameraInitialized || _cameraController == null)
        return false;
      try {
        final XFile file = await _cameraController!.takePicture();
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);
        await _sendToApi(base64Image);
      } catch (e) {
        setState(() {
          _detectedFaces = [
            {'name': 'فشل في المعالجة'}
          ];
          _rawJson = 'Exception: $e';
        });
      }
      await Future.delayed(const Duration(milliseconds: 1000));
      return true;
    });
  }

  Future<void> _sendToApi(String base64Image) async {
    final response = await http.post(
      Uri.parse('https://recproj.fly.dev/recognize'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': base64Image}),
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      setState(() {
        _detectedFaces = List<Map<String, dynamic>>.from(decoded['faces']);
        _rawJson = jsonEncode(decoded);
      });
    } else {
      setState(() {
        _detectedFaces = [
          {'name': 'خطأ في التعرف'}
        ];
        _rawJson = 'Status: ${response.statusCode}';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (!_isCameraInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        CameraPreview(_cameraController!),
        ..._buildFaceBoxes(screenWidth),
        _buildRawJsonBox(),
      ],
    );
  }

  List<Widget> _buildFaceBoxes(double screenWidth) {
    return _detectedFaces.map((face) {
      if (!face.containsKey('top')) return const SizedBox();
      final name = face['name'] ?? '';
      final top = face['top'] * (screenWidth / 640);
      final left = face['left'] * (screenWidth / 640);
      final width = (face['right'] - face['left']) * (screenWidth / 640);
      final height = (face['bottom'] - face['top']) * (screenWidth / 640);
      return Positioned(
        top: top,
        left: left,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(
              color: name == 'غير معروف' ? Colors.red : Colors.green,
              width: 2,
            ),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildRawJsonBox() {
    return Positioned(
      bottom: 10,
      left: 10,
      right: 10,
      child: Container(
        color: const Color(0xCC000000),
        padding: const EdgeInsets.all(8),
        child: Text(
          _rawJson,
          style: const TextStyle(color: Colors.white, fontSize: 10),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
