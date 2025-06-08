import 'package:flutter/material.dart';

class DefaultCaseDetails extends StatelessWidget {
  final Map<String, dynamic> caseData;

  const DefaultCaseDetails({required this.caseData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الحالة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                    Text('الاسم: ${caseData['patientName']}'),
                    if (caseData['patientDetails'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('رقم الهوية: ${caseData['patientDetails']['idNumber']}'),
                          if (caseData['patientDetails']['studentId'] != null)
                            Text('الرقم الجامعي: ${caseData['patientDetails']['studentId']}'),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // تفاصيل الحالة
            _buildDetailItem('التشخيص', caseData['diagnosis']),
            _buildDetailItem('ملاحظات إضافية', caseData['notes']),
            _buildDetailItem('التاريخ', caseData['date']),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'غير متوفر',
            style: const TextStyle(fontSize: 16),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
