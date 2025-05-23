// FaceRecognitionOnlinePage.dart
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FaceRecognitionOnlinePage extends StatefulWidget {
  const FaceRecognitionOnlinePage({super.key});

  @override
  State<FaceRecognitionOnlinePage> createState() =>
      _FaceRecognitionOnlinePageState();
}

class _FaceRecognitionOnlinePageState extends State<FaceRecognitionOnlinePage> {
  late html.VideoElement _videoElement;
  late html.CanvasElement _canvas;
  late Timer _timer;
  List<Map<String, dynamic>> _detectedFaces = [];
  String _rawJson = '';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  void _initCamera() {
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..style.width = '100%'
      ..style.height = 'auto';

    ui.platformViewRegistry
        .registerViewFactory('cameraElement', (int viewId) => _videoElement);

    html.window.navigator.mediaDevices
        ?.getUserMedia({'video': true}).then((stream) {
      _videoElement.srcObject = stream;
      _videoElement.play();

      _canvas = html.CanvasElement(width: 640, height: 480);
      _timer = Timer.periodic(
        const Duration(milliseconds: 30),
            (_) => _sendFrame(),
      );
    }).catchError((e) {
      setState(() {
        _detectedFaces = [
          {'name': 'فشل في الوصول إلى الكاميرا'}
        ];
      });
    });
  }

  void _sendFrame() async {
    try {
      final context = _canvas.context2D;
      context.drawImage(_videoElement, 0, 0);
      final imageDataUrl = _canvas.toDataUrl('image/png');
      final base64Image = imageDataUrl.split(',').last;

      final response = await http.post(
        Uri.parse('http://192.168.1.106:5050/recognize'),
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
          _detectedFaces = [{'name': 'خطأ في التعرف'}];
          _rawJson = 'Status: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detectedFaces = [{'name': 'فشل في المعالجة'}];
        _rawJson = 'Exception: $e';
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Face Recognition Online')),
      body: Stack(
        children: [
          const HtmlElementView(viewType: 'cameraElement'),
          ..._detectedFaces.map((face) {
            if (!face.containsKey('top')) return const SizedBox();

            final name = face['name'] ?? '';
            final top = face['top'] * (screenWidth / 640); // canvas width = 640
            final left = face['left'] * (screenWidth / 640);
            final width = (face['right'] - face['left']) * (screenWidth / 640);
            final height =
                (face['bottom'] - face['top']) * (screenWidth / 640);

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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Text(
                      name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.all(8),
              child: Text(
                _rawJson,
                style: const TextStyle(color: Colors.white, fontSize: 10),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        ],
      ),
    );
  }
}
