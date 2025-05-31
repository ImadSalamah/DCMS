import 'package:flutter/material.dart';

class FaceRecognitionOnlinePage extends StatelessWidget {
  const FaceRecognitionOnlinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Recognition Online')),
      body: const Center(
        child: Text('Face recognition is not supported on this platform.'),
      ),
    );
  }
}
