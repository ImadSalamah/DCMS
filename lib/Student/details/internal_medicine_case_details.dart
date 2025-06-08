import 'package:flutter/material.dart';

class InternalMedicineCaseDetails extends StatelessWidget {
  final Map<String, dynamic> caseData;

  const InternalMedicineCaseDetails({required this.caseData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الحالة الباطنية')),
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
            _buildDetailItem('التاريخ المرضي', caseData['history']),
            _buildDetailItem('الأدوية الموصوفة', caseData['medications']),
            _buildDetailItem('نتائج المختبر', caseData['labResults']),
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
