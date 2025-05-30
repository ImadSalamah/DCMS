import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;

class FaceRecognitionOnlinePageWeb extends StatefulWidget {
  const FaceRecognitionOnlinePageWeb({super.key});

  @override
  State<FaceRecognitionOnlinePageWeb> createState() =>
      _FaceRecognitionOnlinePageWebState();
}

class _FaceRecognitionOnlinePageWebState
    extends State<FaceRecognitionOnlinePageWeb> {
  html.VideoElement? _videoElement;
  html.CanvasElement? _canvas;
  List<Map<String, dynamic>> _detectedFaces = [];
  String _rawJson = '';

  @override
  void initState() {
    super.initState();
    _initWebCamera();
  }

  void _initWebCamera() {
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..style.width = '100%'
      ..style.height = 'auto';
    // Register the video element for Flutter web
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry
        .registerViewFactory('cameraElement', (int viewId) => _videoElement!);
    html.window.navigator.mediaDevices
        ?.getUserMedia({'video': true}).then((stream) {
      _videoElement!.srcObject = stream;
      _videoElement!.play();
      _canvas = html.CanvasElement(width: 640, height: 480);
      _sendWebFrame();
    }).catchError((e) {
      setState(() {
        _detectedFaces = [
          {'name': 'فشل في الوصول إلى الكاميرا'}
        ];
      });
    });
  }

  void _sendWebFrame() async {
    if (!mounted || _videoElement == null || _canvas == null) return;
    try {
      final context = _canvas!.context2D;
      context.drawImage(_videoElement!, 0, 0);
      final imageDataUrl = _canvas!.toDataUrl('image/png');
      final base64Image = imageDataUrl.split(',').last;
      await _sendToApi(base64Image);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detectedFaces = [
          {'name': 'فشل في المعالجة'}
        ];
        _rawJson = 'Exception: $e';
      });
    }
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), _sendWebFrame);
    }
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
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        const HtmlElementView(viewType: 'cameraElement'),
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
