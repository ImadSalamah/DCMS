import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/language_provider.dart';
import 'package:provider/provider.dart';

class AddStudyGroupPage extends StatefulWidget {
  const AddStudyGroupPage({super.key});

  @override
  AddStudyGroupPageState createState() => AddStudyGroupPageState();
}

class AddStudyGroupPageState extends State<AddStudyGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Form fields (nullable)
  String? _selectedGroupName;
  String? _selectedDoctorId;
  int? _requiredCases;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedClinic;
  final List<String> _selectedDays = [];
  String? _studentId;
  Map<String, dynamic>? _selectedStudent;

  // Data lists
  List<Map<String, dynamic>> _doctorsList = [];
  final List<String> _clinicsList = ['العيادة 1', 'العيادة 2', 'العيادة 3'];
  final List<String> _daysList = [
    'السبت',
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس'
  ];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _databaseRef.child('users').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> doctors = [];

        data.forEach((key, value) {
          if (value['role'] == 'doctor') {
            doctors.add({
              'id': key.toString(),
              'name': value['fullName']?.toString() ?? 'Unknown Doctor'
            });
          }
        });

        setState(() => _doctorsList = doctors);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_translate(context, 'error_loading_doctors'))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _findStudent() async {
    final studentId = _studentId?.trim();
    if (studentId == null || studentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_translate(context, 'enter_student_id'))));
      return;
    }

    try {
      setState(() => _isLoading = true);

      final snapshot = await _databaseRef
          .child('users')
          .orderByChild('studentId')
          .equalTo(studentId)
          .once();

      final data = snapshot.snapshot.value;

      if (data != null && data is Map) {
        final studentEntry = data.entries.first;
        final studentData =
            Map<String, dynamic>.from(studentEntry.value as Map);

        if (!mounted) return;
        setState(() {
          _selectedStudent = {
            'id': studentEntry.key,
            'name': studentData['fullName'] ?? 'Unknown Student',
            'studentId': studentData['studentId'] ?? studentId
          };
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_translate(context, 'student_not_found'))));
        setState(() => _selectedStudent = null);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('${_translate(context, 'error_finding_student')}: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final initialTime = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
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

  Future<void> _submitForm() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate())
      return;

    _formKey.currentState!.save();

    if (_selectedGroupName == null ||
        _selectedGroupName!.isEmpty ||
        _selectedDoctorId == null ||
        _requiredCases == null ||
        _startTime == null ||
        _endTime == null ||
        _selectedClinic == null ||
        _selectedDays.isEmpty ||
        _selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_translate(context, 'fill_all_required_fields'))));
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_translate(context, 'user_not_authenticated'))));
        return;
      }

      final doctor =
          _doctorsList.firstWhere((doc) => doc['id'] == _selectedDoctorId);

      await _databaseRef.child('studyGroups').push().set({
        'groupName': _selectedGroupName,
        'doctorId': _selectedDoctorId,
        'doctorName': doctor['name'],
        'requiredCases': _requiredCases,
        'startTime':
            '${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')}',
        'endTime':
            '${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}',
        'clinic': _selectedClinic,
        'days': _selectedDays,
        'students': {
          _selectedStudent!['id']: {
            'name': _selectedStudent!['name'],
            'studentId': _selectedStudent!['studentId']
          }
        },
        'createdBy': user.uid,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_translate(context, 'group_added_successfully'))));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_translate(context, 'error_adding_group'))));
    }
  }

  String _translate(BuildContext context, String key) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final Map<String, Map<String, String>> translations = {
      'add_study_group': {'ar': 'إضافة شعبة دراسية', 'en': 'Add Study Group'},
      'group_name': {'ar': 'اسم الشعبة', 'en': 'Group Name'},
      'select_doctor': {'ar': 'اختر الطبيب', 'en': 'Select Doctor'},
      'required_cases': {'ar': 'عدد الحالات المطلوبة', 'en': 'Required Cases'},
      'start_time': {'ar': 'وقت البدء', 'en': 'Start Time'},
      'end_time': {'ar': 'وقت الانتهاء', 'en': 'End Time'},
      'select_clinic': {'ar': 'اختر العيادة', 'en': 'Select Clinic'},
      'select_days': {'ar': 'اختر الأيام', 'en': 'Select Days'},
      'add_student': {'ar': 'إضافة طالب', 'en': 'Add Student'},
      'student_id': {'ar': 'رقم الطالب الجامعي', 'en': 'Student ID'},
      'search': {'ar': 'بحث', 'en': 'Search'},
      'student_name': {'ar': 'اسم الطالب', 'en': 'Student Name'},
      'submit': {'ar': 'حفظ', 'en': 'Submit'},
      'please_select_student': {
        'ar': 'الرجاء اختيار طالب',
        'en': 'Please select a student'
      },
      'student_not_found': {
        'ar': 'الطالب غير موجود',
        'en': 'Student not found'
      },
      'error_finding_student': {
        'ar': 'خطأ في البحث عن الطالب',
        'en': 'Error finding student'
      },
      'group_added_successfully': {
        'ar': 'تمت إضافة الشعبة بنجاح',
        'en': 'Study group added successfully'
      },
      'error_adding_group': {
        'ar': 'خطأ في إضافة الشعبة',
        'en': 'Error adding study group'
      },
      'required_field': {
        'ar': 'هذا الحقل مطلوب',
        'en': 'This field is required'
      },
      'invalid_number': {'ar': 'رقم غير صحيح', 'en': 'Invalid number'},
      'fill_all_required_fields': {
        'ar': 'الرجاء ملء جميع الحقول المطلوبة',
        'en': 'Please fill all required fields'
      },
      'user_not_authenticated': {
        'ar': 'المستخدم غير مسجل دخول',
        'en': 'User not authenticated'
      },
      'select_time': {'ar': 'اختر الوقت', 'en': 'Select Time'},
      'no_student_selected': {
        'ar': 'لم يتم اختيار طالب',
        'en': 'No student selected'
      },
      'enter_student_id': {
        'ar': 'الرجاء إدخال رقم الطالب',
        'en': 'Please enter student ID'
      },
      'error_loading_doctors': {
        'ar': 'خطأ في تحميل قائمة الأطباء',
        'en': 'Error loading doctors list'
      },
    };
    return translations[key]![languageProvider.currentLocale.languageCode] ??
        key;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_translate(context, 'add_study_group'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_translate(context, 'add_study_group'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Name
              TextFormField(
                decoration: InputDecoration(
                  labelText: _translate(context, 'group_name'),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _translate(context, 'required_field');
                  }
                  return null;
                },
                onSaved: (value) => _selectedGroupName = value,
              ),
              const SizedBox(height: 20),

              // Doctor Selection
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: _translate(context, 'select_doctor'),
                  border: const OutlineInputBorder(),
                ),
                value: _selectedDoctorId,
                items: _doctorsList.map((doctor) {
                  return DropdownMenuItem<String>(
                    value: doctor['id'],
                    child: Text(doctor['name']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedDoctorId = value),
                validator: (value) {
                  if (value == null) {
                    return _translate(context, 'required_field');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Required Cases
              TextFormField(
                decoration: InputDecoration(
                  labelText: _translate(context, 'required_cases'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _translate(context, 'required_field');
                  }
                  if (int.tryParse(value) == null) {
                    return _translate(context, 'invalid_number');
                  }
                  return null;
                },
                onSaved: (value) =>
                    _requiredCases = int.tryParse(value ?? '0') ?? 0,
              ),
              const SizedBox(height: 20),

              // Time Selection
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, true),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: _translate(context, 'start_time'),
                          border: const OutlineInputBorder(),
                        ),
                        child: Text(
                          _startTime != null
                              ? '${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')}'
                              : _translate(context, 'select_time'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, false),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: _translate(context, 'end_time'),
                          border: const OutlineInputBorder(),
                        ),
                        child: Text(
                          _endTime != null
                              ? '${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}'
                              : _translate(context, 'select_time'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Clinic Selection
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: _translate(context, 'select_clinic'),
                  border: const OutlineInputBorder(),
                ),
                value: _selectedClinic,
                items: _clinicsList.map((clinic) {
                  return DropdownMenuItem<String>(
                    value: clinic,
                    child: Text(clinic),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedClinic = value),
                validator: (value) {
                  if (value == null) {
                    return _translate(context, 'required_field');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Days Selection
              Text(
                _translate(context, 'select_days'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                children: _daysList.map((day) {
                  return FilterChip(
                    label: Text(day),
                    selected: _selectedDays.contains(day),
                    onSelected: (selected) => _toggleDay(day),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Student Section
              Text(
                _translate(context, 'add_student'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: _translate(context, 'student_id'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => _studentId = value,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: _findStudent,
                      child: Text(_translate(context, 'search')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_selectedStudent != null) ...[
                Text(
                  '${_translate(context, 'student_name')}: ${_selectedStudent!['name']}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
              ] else if (_studentId != null && _studentId!.isNotEmpty) ...[
                Text(
                  _translate(context, 'student_not_found'),
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
              ],
              const SizedBox(height: 30),

              // Submit Button
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                  ),
                  child: Text(_translate(context, 'submit')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
