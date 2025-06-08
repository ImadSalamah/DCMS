import 'package:flutter/material.dart';

class EvaluateCaseScreen extends StatelessWidget {
  final String groupId;
  final String studentId;
  final String caseId;
  final String caseType;
  final Map<String, dynamic> caseData;
  final VoidCallback? onEvaluate;

  const EvaluateCaseScreen({
    Key? key,
    required this.groupId,
    required this.studentId,
    required this.caseId,
    required this.caseType,
    required this.caseData,
    this.onEvaluate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evaluate Case')),
      body: Center(
        child: Text('Evaluation UI goes here.'),
      ),
    );
  }
}
