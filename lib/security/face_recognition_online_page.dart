import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'face_recognition_online_page_web.dart';
import 'face_recognition_online_page_mobile.dart';

class FaceRecognitionOnlinePage extends StatelessWidget {
  const FaceRecognitionOnlinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Recognition Online')),
      body: kIsWeb
          ? const FaceRecognitionOnlinePageWeb()
          : const FaceRecognitionOnlinePageMobile(),
    );
  }
}
