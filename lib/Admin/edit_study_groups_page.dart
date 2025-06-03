import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class EditStudyGroupsPage extends StatefulWidget {
  const EditStudyGroupsPage({super.key});

  @override
  EditStudyGroupsPageState createState() => EditStudyGroupsPageState();
}

class EditStudyGroupsPageState extends State<EditStudyGroupsPage> {
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref('studyGroups');
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  bool _isLoading = true;
  List<Map<String, dynamic>> _studyGroups = [];
  List<Map<String, dynamic>> _allStudents = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final groupsSnapshot = await _databaseRef.get();
      final studentsSnapshot =
          await _usersRef.orderByChild('role').equalTo('dental_student').get();

      if (!mounted) return;
      setState(() {
        _processGroupsData(groupsSnapshot);
        _processStudentsData(studentsSnapshot);
        _isLoading = false;
      });
    } catch (e) {
      // print('Error loading data: $e');
      setState(() => _isLoading = false);
      _showError('حدث خطأ في تحميل البيانات');
    }
  }

  void _processGroupsData(DataSnapshot snapshot) {
    _studyGroups = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        _studyGroups.add({
          'id': key.toString(),
          ...Map<String, dynamic>.from(value as Map),
        });
      });
    }
  }

  void _processStudentsData(DataSnapshot snapshot) {
    _allStudents = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        final student = value as Map<dynamic, dynamic>;
        if (student['role'] == 'dental_student') {
          _allStudents.add({
            'id': key.toString(),
            'name': student['fullName'] ?? 'Unknown',
            'studentId': student['studentId'] ?? 'N/A'
          });
        }
      });
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> group) async {
    TextEditingController nameController =
        TextEditingController(text: group['groupName']);
    TextEditingController casesController =
        TextEditingController(text: group['requiredCases'].toString());
    String? selectedClinic = group['clinic'];
    List<String> selectedDays = List<String>.from(group['days'] ?? []);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('تعديل الشعبة الدراسية'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'اسم الشعبة'),
                  ),
                  TextField(
                    controller: casesController,
                    decoration: const InputDecoration(
                        labelText: 'عدد الحالات المطلوبة'),
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedClinic,
                    items:
                        ['العيادة 1', 'العيادة 2', 'العيادة 3'].map((clinic) {
                      return DropdownMenuItem(
                        value: clinic,
                        child: Text(clinic),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => selectedClinic = value),
                    decoration: const InputDecoration(labelText: 'العيادة'),
                  ),
                  const SizedBox(height: 10),
                  const Text('أيام الدراسة:'),
                  Wrap(
                    children: [
                      'السبت',
                      'الأحد',
                      'الإثنين',
                      'الثلاثاء',
                      'الأربعاء',
                      'الخميس'
                    ].map((day) {
                      return FilterChip(
                        label: Text(day),
                        selected: selectedDays.contains(day),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedDays.add(day);
                            } else {
                              selectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _updateGroup(
                    group['id'],
                    nameController.text,
                    int.tryParse(casesController.text) ?? 0,
                    selectedClinic ?? '',
                    selectedDays,
                  );
                  if (!mounted) return;
 if (!mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateGroup(String groupId, String name, int cases,
      String clinic, List<String> days) async {
    try {
      await _databaseRef.child(groupId).update({
        'groupName': name,
        'requiredCases': cases,
        'clinic': clinic,
        'days': days,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (!mounted) return;
      _showSuccess('تم تحديث الشعبة بنجاح');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      _showError('حدث خطأ أثناء التحديث');
    }
  }

  Future<void> _showManageStudentsDialog(Map<String, dynamic> group) async {
    final currentStudents = Map<String, dynamic>.from(group['students'] ?? {});
    final availableStudents = _allStudents
        .where((student) => !currentStudents.containsKey(student['id']))
        .toList();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('إدارة طلاب ${group['groupName']}'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('الطلاب الحاليين:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: currentStudents.length,
                      itemBuilder: (context, index) {
                        final studentId = currentStudents.keys.elementAt(index);
                        final student = currentStudents[studentId];
                        return ListTile(
                          title: Text(student['name']),
                          subtitle: Text(student['studentId']),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red),
                            onPressed: () async {
                              await _removeStudent(group['id'], studentId);
                              setState(() {
                                currentStudents.remove(studentId);
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  const Text('الطلاب المتاحين للإضافة:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableStudents.length,
                      itemBuilder: (context, index) {
                        final student = availableStudents[index];
                        return ListTile(
                          title: Text(student['name']),
                          subtitle: Text(student['studentId']),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.green),
                            onPressed: () async {
                              await _addStudent(group['id'], student);
                              setState(() {
                                currentStudents[student['id']] = {
                                  'name': student['name'],
                                  'studentId': student['studentId']
                                };
                                availableStudents.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تم'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addStudent(String groupId, Map<String, dynamic> student) async {
    try {
      await _databaseRef
          .child('$groupId/students/${student['id']}')
          .set({'name': student['name'], 'studentId': student['studentId']});
      if (!mounted) return;
      _showSuccess('تم إضافة الطالب بنجاح');
    } catch (e) {
      if (!mounted) return;
      _showError('حدث خطأ أثناء إضافة الطالب');
    }
  }

  Future<void> _removeStudent(String groupId, String studentId) async {
    try {
      await _databaseRef.child('$groupId/students/$studentId').remove();
      if (!mounted) return;
      _showSuccess('تم إزالة الطالب بنجاح');
    } catch (e) {
      if (!mounted) return;
      _showError('حدث خطأ أثناء إزالة الطالب');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الشعب الدراسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _studyGroups.isEmpty
              ? const Center(child: Text('لا توجد شعب دراسية'))
              : ListView.builder(
                  itemCount: _studyGroups.length,
                  itemBuilder: (context, index) {
                    final group = _studyGroups[index];
                    return _buildGroupCard(group);
                  },
                ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final students = group['students'] as Map<dynamic, dynamic>? ?? {};

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  group['groupName'] ?? 'بدون اسم',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditDialog(group),
                    ),
                    IconButton(
                      icon: const Icon(Icons.people, color: Colors.green),
                      onPressed: () => _showManageStudentsDialog(group),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('الطبيب', group['doctorName'] ?? 'غير معين'),
            _buildInfoRow('العيادة', group['clinic'] ?? 'غير محددة'),
            _buildInfoRow(
                'الوقت', '${group['startTime']} - ${group['endTime']}'),
            _buildInfoRow(
                'الأيام', (group['days'] as List?)?.join('، ') ?? 'غير محددة'),
            _buildInfoRow(
                'عدد الحالات', group['requiredCases']?.toString() ?? '0'),
            const SizedBox(height: 8),
            const Text('الطلاب المسجلون:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (students.isEmpty)
              const Text('لا يوجد طلاب مسجلون',
                  style: TextStyle(color: Colors.grey))
            else
              ...students.entries.map((entry) {
                final student = entry.value as Map<dynamic, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 4),
                      Text('${student['name']} (${student['studentId']})'),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }
}
