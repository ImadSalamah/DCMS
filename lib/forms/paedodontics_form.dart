import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaedodonticsForm extends StatefulWidget {
  const PaedodonticsForm({super.key});

  @override
  State<PaedodonticsForm> createState() => _PaedodonticsFormState();
}

class _PaedodonticsFormState extends State<PaedodonticsForm> {
  int historyCases = 0;
  int fissureCases = 0;
  bool isSubmitting = false;
  String? lastSubmittedCaseKey;
  String? lastCaseStatus;
  int? lastCaseMark;
  String? lastDoctorComment;

  Future<void> _loadLastCase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final db = FirebaseDatabase.instance.ref();
    final snapshot = await db.child('paedodonticsCases').orderByChild('studentId').equalTo(user.uid).get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final sorted = data.entries.toList()
        ..sort((a, b) => (b.value['submittedAt'] ?? 0).compareTo(a.value['submittedAt'] ?? 0));
      final last = sorted.first.value;
      lastSubmittedCaseKey = sorted.first.key;
      lastCaseStatus = last['status'];
      lastCaseMark = last['mark'];
      lastDoctorComment = last['doctorComment'];
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLastCase();
  }

  Future<void> submitCase() async {
    setState(() => isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول')));
      setState(() => isSubmitting = false);
      return;
    }
    final DatabaseReference db = FirebaseDatabase.instance.ref();
    final caseData = {
      'studentId': user.uid,
      'historyCases': historyCases,
      'fissureCases': fissureCases,
      'status': 'pending', // الحالة معلقة
      'mark': null, // لم يتم التقييم بعد
      'doctorComment': null,
      'submittedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await db.child('paedodonticsCases').push().set(caseData);
    await _loadLastCase();
    setState(() => isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الحالة للدكتور المشرف')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paedodontics I clinic Form')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clinical Requirements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                title: const Text('History taking, examination, & treatment planning'),
                subtitle: const Text('المطلوب: 3 حالات'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: historyCases > 0 ? () => setState(() => historyCases--) : null,
                    ),
                    Text('$historyCases'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: historyCases < 3 ? () => setState(() => historyCases++) : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                title: const Text('Fissure sealants'),
                subtitle: const Text('المطلوب: 6 حالات'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: fissureCases > 0 ? () => setState(() => fissureCases--) : null,
                    ),
                    Text('$fissureCases'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: fissureCases < 6 ? () => setState(() => fissureCases++) : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (lastCaseStatus == 'graded') ...[
              Card(
                color: Colors.green[50],
                child: ListTile(
                  title: const Text('تم تقييم آخر حالة'),
                  subtitle: Text('العلامة: ${lastCaseMark ?? 'بدون علامة'}\nملاحظة الدكتور: ${lastDoctorComment ?? '-'}'),
                ),
              ),
            ] else if (lastCaseStatus == 'pending') ...[
              Card(
                color: Colors.orange[50],
                child: const ListTile(
                  title: Text('آخر حالة قيد المراجعة من الدكتور'),
                ),
              ),
            ] else if (lastCaseStatus == 'rejected') ...[
              Card(
                color: Colors.red[50],
                child: ListTile(
                  title: const Text('آخر حالة بحاجة لتعديل'),
                  subtitle: Text('ملاحظة الدكتور: ${lastDoctorComment ?? '-'}'),
                ),
              ),
            ],
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: (isSubmitting || lastCaseStatus == 'pending') ? null : submitCase,
                child: isSubmitting ? const CircularProgressIndicator() : const Text('إرسال الحالة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
