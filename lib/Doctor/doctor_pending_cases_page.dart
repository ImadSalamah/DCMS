import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DoctorPendingCasesPage extends StatefulWidget {
  const DoctorPendingCasesPage({super.key});

  @override
  State<DoctorPendingCasesPage> createState() => _DoctorPendingCasesPageState();
}

class _DoctorPendingCasesPageState extends State<DoctorPendingCasesPage> {
  final DatabaseReference db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> pendingCases = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingCases();
  }

  Future<void> _loadPendingCases() async {
    setState(() => isLoading = true);
    final snapshot = await db.child('pendingCases').get();
    final List<Map<String, dynamic>> cases = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      // Loop over groupId
      data.forEach((groupId, groupCases) {
        if (groupCases is Map) {
          // Loop over studentId
          groupCases.forEach((studentId, studentCases) {
            if (studentCases is Map) {
              // Loop over caseId
              studentCases.forEach((caseId, caseData) {
                if (caseData is Map && caseData['status'] == 'pending') {
                  final caseMap = Map<String, dynamic>.from(caseData);
                  caseMap['key'] = caseId;
                  caseMap['groupId'] = groupId;
                  caseMap['studentId'] = studentId;
                  cases.add(caseMap);
                }
              });
            }
          });
        }
      });
    }
    setState(() {
      pendingCases = cases;
      isLoading = false;
    });
  }

  void _showCaseDialog(Map<String, dynamic> caseData) {
    final markController = TextEditingController();
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تقييم حالة الطالب'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم الطالب: ${caseData['studentId']}'),
              Text('History Cases: ${caseData['historyCases']}'),
              Text('Fissure Cases: ${caseData['fissureCases']}'),
              const SizedBox(height: 16),
              TextField(
                controller: markController,
                decoration:
                    const InputDecoration(labelText: 'العلامة (اختياري)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                    labelText: 'ملاحظة للطالِب (اختياري)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // إرجاع الحالة للطالب
              await db.child('pendingCases').child(caseData['key']).update({
                'status': 'rejected',
                'doctorComment': commentController.text,
              });
              Navigator.pop(context);
              _loadPendingCases();
            },
            child: const Text('إرجاع للتعديل'),
          ),
          ElevatedButton(
            onPressed: () async {
              // تقييم الحالة
              await db.child('pendingCases').child(caseData['key']).update({
                'status': 'graded',
                'mark': markController.text.isNotEmpty
                    ? int.tryParse(markController.text)
                    : null,
                'doctorComment': commentController.text,
              });

              // Update studentCourseProgress
              final studentId = caseData['studentId'];
              const courseId = '080114140'; // Paedodontics I clinic
              // Determine which case type to increment
              // If both historyCases and fissureCases are present, increment both if >0
              if ((caseData['historyCases'] ?? 0) > 0) {
                final progressRef = db
                    .child('studentCourseProgress')
                    .child(studentId)
                    .child(courseId)
                    .child('historyCasesCompleted');
                final progressSnap = await progressRef.get();
                int current = (progressSnap.value ?? 0) as int;
                await progressRef
                    .set(current + (caseData['historyCases'] ?? 0));
              }
              if ((caseData['fissureCases'] ?? 0) > 0) {
                final progressRef = db
                    .child('studentCourseProgress')
                    .child(studentId)
                    .child(courseId)
                    .child('fissureCasesCompleted');
                final progressSnap = await progressRef.get();
                int current = (progressSnap.value ?? 0) as int;
                await progressRef
                    .set(current + (caseData['fissureCases'] ?? 0));
              }

              Navigator.pop(context);
              _loadPendingCases();
            },
            child: const Text('حفظ التقييم'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الحالات المعلقة - طب أسنان الأطفال')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingCases.isEmpty
              ? const Center(child: Text('لا يوجد حالات معلقة'))
              : ListView.builder(
                  itemCount: pendingCases.length,
                  itemBuilder: (context, index) {
                    final caseData = pendingCases[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text('طالب: ${caseData['studentId']}'),
                        subtitle: Text(
                            'تاريخ الإرسال: ${DateTime.fromMillisecondsSinceEpoch(caseData['submittedAt']).toString().substring(0, 16)}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showCaseDialog(caseData),
                      ),
                    );
                  },
                ),
    );
  }
}
