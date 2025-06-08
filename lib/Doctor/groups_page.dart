import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DoctorGroupsPage extends StatefulWidget {
  const DoctorGroupsPage({super.key});

  @override
  State<DoctorGroupsPage> createState() => _DoctorGroupsPageState();
}

class _DoctorGroupsPageState extends State<DoctorGroupsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final snapshot = await _dbRef.child('studyGroups').get();
    final List<Map<String, dynamic>> groups = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        groups.add({'id': key, ...Map<String, dynamic>.from(value as Map)});
      });
    }
    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  void _openGroupMarks(Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupMarksPage(group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شعب الإشراف')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final group = _groups[index];
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: Text(group['courseName'] ?? 'بدون اسم'),
                    subtitle: Text('الشعبة: ${group['groupNumber'] ?? ''}'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => _openGroupMarks(group),
                  ),
                );
              },
            ),
    );
  }
}

class GroupMarksPage extends StatefulWidget {
  final Map<String, dynamic> group;
  const GroupMarksPage({required this.group, super.key});

  @override
  State<GroupMarksPage> createState() => _GroupMarksPageState();
}

class _GroupMarksPageState extends State<GroupMarksPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentsAndCases();
  }

  Future<void> _loadStudentsAndCases() async {
    final groupId = widget.group['id'];
    final groupDataSnap =
        await _dbRef.child('studyGroups').child(groupId).get();
    final studentsMap =
        groupDataSnap.child('students').value as Map<dynamic, dynamic>? ?? {};
    final List<Map<String, dynamic>> students = [];
    for (final entry in studentsMap.entries) {
      final studentId = entry.key;
      final studentSnap = await _dbRef.child('users').child(studentId).get();
      final studentData = studentSnap.value as Map<dynamic, dynamic>? ?? {};
      // جلب اسم الطالب من studentsMap أو users
      String studentName = studentData['fullName'] ?? studentData['name'] ?? '';
      if (studentName.isEmpty) {
        studentName = entry.value['fullName'] ?? entry.value['name'] ?? '';
      }
      // جلب الحالات المسلمة لهذا الطالب في هذه الشعبة
      final casesSnap = await _dbRef
          .child('paedodonticsCases')
          .orderByChild('studentId')
          .equalTo(studentId)
          .get();
      final List<Map<String, dynamic>> cases = [];
      if (casesSnap.exists) {
        final allCases = casesSnap.value as Map<dynamic, dynamic>;
        allCases.forEach((caseKey, caseData) {
          if (caseData['groupId'] == groupId) {
            cases.add({...Map<String, dynamic>.from(caseData), 'id': caseKey});
          }
        });
      }
      students.add({
        'id': studentId,
        'name': studentName,
        'cases': cases,
      });
    }
    // ترتيب الطلاب حسب الاسم
    students.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    setState(() {
      _students = students;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final paedoCaseTitles = [
      ...List.generate(3, (i) => 'تاريخ وفحص ${i + 1}'),
      ...List.generate(6, (i) => 'سد شقوق ${i + 1}'),
    ];

    // دالة بحث متقدمة: تعيد أحدث graded فقط وتتجاهل الحالات التي caseType=null
    Map<String, dynamic>? findCase(
        List<Map<String, dynamic>> cases, String type, int number) {
      // استبعاد الحالات التي caseType=null
      final filtered = cases.where((c) =>
          c['caseType'] == type &&
          c['caseNumber'].toString() == number.toString());
      // فقط الحالات graded
      final graded = filtered
          .where((c) => c['status'] == 'graded' && c['caseType'] != null);
      if (graded.isEmpty) return null;
      // إذا تكررت، اختر الأعلى mark (أو doctorGrade/grade)
      graded.toList().sort((a, b) {
        final ma = a['doctorGrade'] ?? a['mark'] ?? a['grade'] ?? 0;
        final mb = b['doctorGrade'] ?? b['mark'] ?? b['grade'] ?? 0;
        return mb.compareTo(ma);
      });
      return graded.first;
    }

    return Scaffold(
      appBar: AppBar(
          title: Text('علامات الشعبة: ${widget.group['groupNumber'] ?? ''}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('الطالب')),
                  ...paedoCaseTitles.map((t) => DataColumn(label: Text(t))),
                ],
                rows: _students.map((student) {
                  final cases = student['cases'] as List<Map<String, dynamic>>;
                  // طباعة تصحيحية لكل طالب
                  debugPrint('Student: ${student['name']}');
                  for (final c in cases) {
                    debugPrint(
                        'Case: ${c['caseType']} ${c['caseNumber']}, Status: ${c['status']}, Mark: ${c['doctorGrade'] ?? c['mark'] ?? c['grade']}');
                  }
                  List<DataCell> cells = [
                    DataCell(Text(student['name'] ?? '')),
                  ];
                  for (int i = 0; i < 9; i++) {
                    final type = i < 3 ? 'history' : 'fissure';
                    final number = i < 3 ? i + 1 : i - 2;
                    final caseData = findCase(cases, type, number);
                    String mark = '-';
                    if (caseData != null) {
                      // فقط إذا كانت الحالة graded
                      final status = caseData['status'];
                      final m = caseData['doctorGrade'] ??
                          caseData['mark'] ??
                          caseData['grade'];
                      if (status == 'graded' &&
                          m != null &&
                          m.toString().isNotEmpty) {
                        mark = m.toString();
                      }
                    }
                    cells.add(DataCell(Text(mark)));
                  }
                  return DataRow(cells: cells);
                }).toList(),
              ),
            ),
    );
  }
}
