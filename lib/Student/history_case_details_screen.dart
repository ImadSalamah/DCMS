import 'package:flutter/material.dart';

class HistoryCaseDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> caseData;
  final bool isViewOnly;

  const HistoryCaseDetailsScreen({
    super.key,
    required this.caseData,
    this.isViewOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History Case Details')),
      body: const Center(child: Text('History Case Details Placeholder')),
    );
  }
}
