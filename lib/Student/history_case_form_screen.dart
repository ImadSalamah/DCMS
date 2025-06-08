import 'package:flutter/material.dart';

class HistoryCaseFormScreen extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String groupId;
  final VoidCallback? onSave;

  const HistoryCaseFormScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.groupId,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History Case Form')),
      body: const Center(child: Text('History Case Form Placeholder')),
    );
  }
}
