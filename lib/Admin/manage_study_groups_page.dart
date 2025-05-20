import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminManageGroupsPage extends StatefulWidget {
  const AdminManageGroupsPage({super.key});

  @override
  _AdminManageGroupsPageState createState() => _AdminManageGroupsPageState();
}

class _AdminManageGroupsPageState extends State<AdminManageGroupsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  String? _selectedCourse;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedClinic;
  List<String> _selectedDays = [];
  String? _selectedDoctorId;
  List<String> _selectedStudents = [];
  String? _groupNumber;
  String? _editingGroupId;

  // قوائم البيانات
  final List<String> _courses = [
    'Paedodontics I (080114140)',
    'Orthodontics (080114141)',
    'Oral Surgery (080114142)'
  ];

  final List<String> _clinics = List.generate(11, (index) => 'Clinic ${String.fromCharCode(65 + index)}');
  final List<String> _days = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _loadStudents();
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    try {
      final snapshot = await _dbRef.child('users').orderByChild('role').equalTo('doctor').get();
      if (snapshot.exists) {
        setState(() {
          _doctors = [];
          final data = snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            _doctors.add({
              'id': key.toString(),
              'name': value['fullName']?.toString() ?? 'غير معروف',
              'specialty': value['specialty']?.toString() ?? 'غير محدد'
            });
          });
        });
      }
    } catch (e) {
      print('Error loading doctors: $e');
    }
  }

  Future<void> _loadStudents() async {
    try {
      final snapshot = await _dbRef.child('students').get();
      if (snapshot.exists) {
        setState(() {
          _allStudents = [];
          _filteredStudents = [];
          final data = snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            _allStudents.add({
              'id': key.toString(),
              'uid': value['uid']?.toString() ?? '',
              'name': value['fullName']?.toString() ?? 'طالب غير معروف',
              'studentId': value['studentId']?.toString() ?? 'غير معروف',
              'email': value['email']?.toString() ?? '',
            });
          });
          _filteredStudents = List.from(_allStudents);
        });
      }
    } catch (e) {
      print('Error loading students: $e');
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        final name = student['name'].toString().toLowerCase();
        final studentId = student['studentId'].toString().toLowerCase();
        final email = student['email'].toString().toLowerCase();
        return name.contains(query) ||
            studentId.contains(query) ||
            email.contains(query);
      }).toList();
    });
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _editGroup(Map group, String groupId) {
    setState(() {
      _editingGroupId = groupId;
      _selectedCourse = group['courseName'];
      _selectedDoctorId = group['doctorId'];
      _selectedClinic = group['clinic'];

      // تحويل وقت البداية
      final startParts = group['startTime'].toString().split(':');
      _startTime = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );

      // تحويل وقت النهاية
      final endParts = group['endTime'].toString().split(':');
      _endTime = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );

      _selectedDays = List<String>.from(group['days']);
      _selectedStudents = List<String>.from((group['students'] as Map).keys.toList());
      _groupNumber = group['groupNumber'];
      _groupNumberController.text = _groupNumber ?? '';
    });
  }

  Future<void> _saveGroup() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب اختيار يوم واحد على الأقل')),
        );
        return;
      }

      if (_selectedStudents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب اختيار طالب واحد على الأقل')),
        );
        return;
      }

      if (_groupNumberController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب إدخال رقم الشعبة')),
        );
        return;
      }

      try {
        final user = _auth.currentUser;
        if (user == null) return;

        final doctor = _doctors.firstWhere((doc) => doc['id'] == _selectedDoctorId);

        // تحويل الطلاب المختارين إلى Map باستخدام uid
        final studentsMap = {};
        for (var studentId in _selectedStudents) {
          final student = _allStudents.firstWhere((s) => s['id'] == studentId);
          studentsMap[student['uid']] = {
            'name': student['name'],
            'studentId': student['studentId'],
            'email': student['email']
          };
        }

        final groupData = {
          'courseName': _selectedCourse,
          'courseId': _selectedCourse!.split('(').last.replaceAll(')', '').trim(),
          'doctorId': _selectedDoctorId,
          'doctorName': doctor['name'],
          'startTime': '${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')}',
          'endTime': '${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}',
          'clinic': _selectedClinic,
          'days': _selectedDays,
          'students': studentsMap,
          'groupNumber': _groupNumberController.text,
          'createdBy': user.uid,
          'updatedAt': DateTime.now().toString(),
        };

        if (_editingGroupId == null) {
          groupData['createdAt'] = DateTime.now().toString();
          await _dbRef.child('studyGroups').push().set(groupData);
        } else {
          await _dbRef.child('studyGroups/$_editingGroupId').update(groupData);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editingGroupId == null
              ? 'تم إنشاء الشعبة بنجاح'
              : 'تم تحديث الشعبة بنجاح')),
        );

        // إعادة تعيين الحقول
        _resetForm();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    }
  }

  Future<void> _deleteGroup(String groupId) async {
    try {
      await _dbRef.child('studyGroups/$groupId').remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الشعبة بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الحذف: $e')),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _editingGroupId = null;
      _selectedCourse = null;
      _startTime = null;
      _endTime = null;
      _selectedClinic = null;
      _selectedDays = [];
      _selectedDoctorId = null;
      _selectedStudents = [];
      _groupNumber = null;
      _groupNumberController.clear();
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الشعب السريرية'),
        centerTitle: true,
        actions: [
          if (_editingGroupId != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _resetForm,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رقم الشعبة
              TextFormField(
                controller: _groupNumberController,
                decoration: const InputDecoration(
                  labelText: 'رقم الشعبة',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
                onSaved: (value) => _groupNumber = value,
              ),

              const SizedBox(height: 20),

              // اختيار المساق
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'اختر المساق',
                  border: OutlineInputBorder(),
                ),
                value: _selectedCourse,
                items: _courses.map<DropdownMenuItem<String>>((course) {
                  return DropdownMenuItem<String>(
                    value: course,
                    child: Text(course),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedCourse = value),
                validator: (value) => value == null ? 'مطلوب' : null,
              ),

              const SizedBox(height: 20),

              // اختيار الطبيب المشرف
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'اختر الطبيب المشرف',
                  border: OutlineInputBorder(),
                ),
                value: _selectedDoctorId,
                items: _doctors.map<DropdownMenuItem<String>>((doctor) {
                  return DropdownMenuItem<String>(
                    value: doctor['id'] as String,
                    child: Text('${doctor['name']} - ${doctor['specialty']}'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedDoctorId = value),
                validator: (value) => value == null ? 'مطلوب' : null,
              ),

              const SizedBox(height: 20),

              // اختيار العيادة (من A إلى K)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'اختر العيادة',
                  border: OutlineInputBorder(),
                ),
                value: _selectedClinic,
                items: _clinics.map<DropdownMenuItem<String>>((clinic) {
                  return DropdownMenuItem<String>(
                    value: clinic,
                    child: Text(clinic),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedClinic = value),
                validator: (value) => value == null ? 'مطلوب' : null,
              ),

              const SizedBox(height: 20),

              // اختيار الوقت
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'وقت البدء',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _startTime != null
                              ? '${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')}'
                              : 'اختر الوقت',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'وقت الانتهاء',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _endTime != null
                              ? '${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}'
                              : 'اختر الوقت',
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // اختيار الأيام
              const Text(
                'أيام المحاضرة:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                children: _days.map((day) {
                  return FilterChip(
                    label: Text(day),
                    selected: _selectedDays.contains(day),
                    onSelected: (selected) => _toggleDay(day),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // اختيار الطلاب
              const Text(
                'اختر الطلاب:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // حقل البحث عن الطلاب
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'ابحث عن طالب',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              // قائمة الطلاب مع إمكانية التصفية
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _filteredStudents.isEmpty
                    ? const Center(child: Text('لا توجد نتائج'))
                    : ListView.builder(
                  itemCount: _filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = _filteredStudents[index];
                    return CheckboxListTile(
                      title: Text('${student['name']}'),
                      subtitle: Text('${student['studentId']} - ${student['email']}'),
                      value: _selectedStudents.contains(student['id']),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedStudents.add(student['id'] as String);
                          } else {
                            _selectedStudents.remove(student['id']);
                          }
                        });
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _saveGroup,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: Text(_editingGroupId == null ? 'إنشاء شعبة' : 'تحديث الشعبة'),
                  ),
                  if (_editingGroupId != null)
                    ElevatedButton(
                      onPressed: _resetForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                      child: const Text('إلغاء'),
                    ),
                ],
              ),

              const SizedBox(height: 40),

              const Text(
                'الشعب الحالية:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              // عرض الشعب الحالية
              StreamBuilder(
                stream: _dbRef.child('studyGroups').onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
                  if (data == null || data.isEmpty) {
                    return const Center(child: Text('لا توجد شعب مسجلة'));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final key = data.keys.elementAt(index);
                      final group = data[key] as Map;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          title: Text('الشعبة ${group['groupNumber']} - ${group['courseName']}'),
                          subtitle: Text('بإشراف د. ${group['doctorName']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editGroup(group, key),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteGroup(key),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('الوقت: ${group['startTime']} - ${group['endTime']}'),
                                  Text('الأيام: ${(group['days'] as List?)?.join('، ') ?? 'غير محدد'}'),
                                  Text('العيادة: ${group['clinic']}'),
                                  const SizedBox(height: 10),
                                  const Text('الطلاب:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ...(group['students'] as Map? ?? {}).values.map<Widget>((student) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Text(' - ${student['name']} (${student['studentId']})'),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}