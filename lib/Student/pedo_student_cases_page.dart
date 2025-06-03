import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../forms/paedodontics_form.dart';

class PedoStudentCasesPage extends StatefulWidget {
  final String? courseId; // Pass courseId for generic use
  const PedoStudentCasesPage({super.key, this.courseId});

  @override
  State<PedoStudentCasesPage> createState() => _PedoStudentCasesPageState();
}

class _PedoStudentCasesPageState extends State<PedoStudentCasesPage> {
  List<Map<String, dynamic>> _requiredCases = [];
  Map<String, int> _completedCases = {};
  bool _isLoading = true;
  String? _courseId;

  @override
  void initState() {
    super.initState();
    _courseId = widget.courseId ?? '080114140'; // fallback for paedodontics
    _loadRequirementsAndProgress();
  }

  Future<void> _loadRequirementsAndProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _courseId == null) return;
    final db = FirebaseDatabase.instance.ref();
    // Fetch requirements
    final reqSnap = await db
        .child('studentCourseProgress')
        .child(user.uid)
        .child(_courseId!)
        .get();
    if (!reqSnap.exists) {
      setState(() {
        _requiredCases = [];
        _completedCases = {};
        _isLoading = false;
      });
      return;
    }
    final reqData = reqSnap.value as Map<dynamic, dynamic>;
    final List<Map<String, dynamic>> requiredCases = [];
    final Map<String, int> completedCases = {};
    reqData.forEach((key, value) {
      if (key.endsWith('Required')) {
        final type = key
            .replaceAll('CasesRequired', '')
            .replaceAll('Required', '')
            .toLowerCase();
        final completedKey = key.replaceAll('Required', 'Completed');
        requiredCases.add({
          'type': type,
          'title': _getCaseTitle(type),
          'required': value,
        });
        completedCases[type] = (reqData[completedKey] ?? 0) as int;
      }
    });
    setState(() {
      _requiredCases = requiredCases;
      _completedCases = completedCases;
      _isLoading = false;
    });
  }

  String _getCaseTitle(String type) {
    // You can expand this mapping as needed for other courses/case types
    switch (type) {
      case 'history':
        return 'History taking, examination, & treatment planning';
      case 'fissure':
        return 'Fissure sealants';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  void _openForm(BuildContext context, String type) async {
    // TODO: Pass courseId/type to the correct form for generic support
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaedodonticsForm()),
    );
    _loadRequirementsAndProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الحالات المطلوبة')), // Generic title
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requiredCases.length,
              itemBuilder: (context, index) {
                final item = _requiredCases[index];
                final completed = _completedCases[item['type']] ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    title: Text(item['title']),
                    subtitle: Text(
                        'المطلوب: ${item['required']} | المنجز: $completed'),
                    trailing: ElevatedButton(
                      onPressed: completed < (item['required'] as int)
                          ? () => _openForm(context, item['type'])
                          : null,
                      child: const Text('عَبِّئ الحالة'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
