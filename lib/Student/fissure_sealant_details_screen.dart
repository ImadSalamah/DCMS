import 'package:flutter/material.dart';

class FissureSealantDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> caseData;
  final bool isViewOnly;

  const FissureSealantDetailsScreen({
    super.key,
    required this.caseData,
    this.isViewOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fissure Sealant Details')),
      body: const Center(child: Text('Fissure Sealant Details Placeholder')),
    );
  }
}
