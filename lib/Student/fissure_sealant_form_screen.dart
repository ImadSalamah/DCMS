import 'package:flutter/material.dart';

class FissureSealantFormScreen extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String groupId;
  final VoidCallback? onSave;

  const FissureSealantFormScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.groupId,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fissure Sealant Form')),
      body: const Center(child: Text('Fissure Sealant Form Placeholder')),
    );
  }
}
