import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../forms/paedodontics_form.dart'; // استيراد الفورم من المسار الصحيح

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

    // جلب جميع المستخدمين: المفتاح هو UID
    final usersSnap = await db.child('users').get();
    Map<String, String> studentIdToName = {};

    if (usersSnap.exists && usersSnap.value is Map) {
      final usersMap = usersSnap.value as Map;
      for (var userEntry in usersMap.entries) {
        final uid = userEntry.key.toString(); // المفتاح هو studentId
        final user = userEntry.value;

        if (user is Map) {
          String fullName = '';

          if (user['fullName'] != null && user['fullName'].toString().trim().isNotEmpty) {
            fullName = user['fullName'].toString().trim();
          } else {
            fullName = [
              user['firstName'],
              user['fatherName'],
              user['grandfatherName'],
              user['familyName'],
            ].where((e) => e != null && e.toString().trim().isNotEmpty)
             .map((e) => e.toString().trim())
             .join(' ');
          }

          studentIdToName[uid] = fullName.isNotEmpty ? fullName : uid;
        }
      }
    }

    // جلب الحالات المعلقة
    final snapshot = await db.child('paedodonticsCases').orderByChild('status').equalTo('pending').get();
    final List<Map<String, dynamic>> cases = [];

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final caseData = Map<String, dynamic>.from(entry.value as Map);
        caseData['key'] = entry.key;

        if (caseData['studentId'] != null) {
          final sid = caseData['studentId'].toString();
          caseData['studentName'] = studentIdToName[sid] ?? sid;
        }

        cases.add(caseData);
      }
    }

    setState(() {
      pendingCases = cases;
      isLoading = false;
    });
  }

  void _showCaseDialog(Map<String, dynamic> caseData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaedodonticsForm(
          groupId: caseData['groupId'],
          caseNumber: caseData['caseNumber'],
          patient: (caseData['patient'] is Map)
              ? Map<String, dynamic>.from(caseData['patient'])
              : {},
          courseId: caseData['courseId'] ?? '080114140',
          caseType: caseData['caseType'],
          initialData: caseData,
          onSave: _loadPendingCases,
        ),
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
                    final locked = caseData['_locked'] == true;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: locked ? Colors.grey[200] : null,
                      child: ListTile(
                        title: Text('طالب: ${caseData['studentName'] ?? caseData['studentId']}'),
                        subtitle: Text(
                          'تاريخ الإرسال: ${DateTime.fromMillisecondsSinceEpoch(caseData['submittedAt']).toString().substring(0, 16)}',
                        ),
                        trailing: locked
                            ? const Icon(Icons.lock, color: Colors.grey)
                            : const Icon(Icons.chevron_right),
                        onTap: locked ? null : () => _showCaseDialog(caseData),
                      ),
                    );
                  },
                ),
    );
  }
}
