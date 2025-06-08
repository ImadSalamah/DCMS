import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class DefaultCaseForm extends StatefulWidget {
  final String groupId;
  final String courseId;
  final int caseNumber;
  final Map<String, dynamic> patient;
  final Function() onSave;

  const DefaultCaseForm({
    required this.groupId,
    required this.courseId,
    required this.caseNumber,
    required this.patient,
    required this.onSave,
  });

  @override
  State<DefaultCaseForm> createState() => _DefaultCaseFormState();
}

class _DefaultCaseFormState extends State<DefaultCaseForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newCase = {
        'caseNumber': widget.caseNumber,
        'patientName': widget.patient['fullName'],
        'patientId': widget.patient['id'],
        'patientDetails': {
          'idNumber': widget.patient['idNumber'],
          'studentId': widget.patient['studentId'],
          'phone': widget.patient['phone'],
        },
        'diagnosis': _diagnosisController.text,
        'notes': _notesController.text,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'courseId': widget.courseId,
        'submittedAt': ServerValue.timestamp,
        'status': 'pending',
      };

      await FirebaseDatabase.instance
          .ref()
          .child('pendingCases')
          .child(widget.groupId)
          .child(user.uid)
          .push()
          .set(newCase);

      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('حالة عامة ${widget.caseNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات المريض
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'معلومات المريض:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('الاسم: ${widget.patient['fullName']}'),
                      Text('رقم الهوية: ${widget.patient['idNumber']}'),
                      if (widget.patient['studentId'] != null)
                        Text('الرقم الجامعي: ${widget.patient['studentId']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // حقول النموذج
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: 'التشخيص',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات إضافية',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  child: const Text('حفظ الحالة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
