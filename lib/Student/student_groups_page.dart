import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MaterialApp(
    home: StudentGroupsPage(),
  ));
}

class StudentGroupsPage extends StatefulWidget {
  const StudentGroupsPage({super.key});

  @override
  StudentGroupsPageState createState() => StudentGroupsPageState();
}

class StudentGroupsPageState extends State<StudentGroupsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _studentGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentGroups();
  }

  Future<void> _loadStudentGroups() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _dbRef.child('studyGroups').get();
      if (snapshot.exists) {
        final allGroups = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> groups = [];

        allGroups.forEach((groupId, groupData) {
          final students =
              groupData['students'] as Map<dynamic, dynamic>? ?? {};
          if (students.containsKey(user.uid)) {
            groups.add({
              'id': groupId.toString(),
              'groupNumber':
                  groupData['groupNumber']?.toString() ?? 'غير معروف',
              'courseId': groupData['courseId']?.toString() ?? '',
              'courseName': groupData['courseName']?.toString() ?? 'غير معروف',
              'requiredCases': groupData['requiredCases'] ?? 3,
            });
          }
        });

        setState(() {
          _studentGroups = groups;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToLogbook(BuildContext context, Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CasesScreen(
          groupId: group['id'],
          courseId: group['courseId'],
          courseName: group['courseName'],
          requiredCases: group['requiredCases'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شعبي الدراسية'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _studentGroups.isEmpty
              ? const Center(child: Text('لا توجد شعب مسجلة لك'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _studentGroups.length,
                  itemBuilder: (context, index) {
                    final group = _studentGroups[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: Text(group['courseName']),
                        subtitle: Text('الشعبة ${group['groupNumber']}'),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => _navigateToLogbook(context, group),
                      ),
                    );
                  },
                ),
    );
  }
}

class _CasesScreen extends StatefulWidget {
  final String groupId;
  final String courseId;
  final String courseName;
  final int requiredCases;

  const _CasesScreen({
    required this.groupId,
    required this.courseId,
    required this.courseName,
    required this.requiredCases,
  });

  @override
  State<_CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<_CasesScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _submittedCases = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Map<String, dynamic>? _selectedPatient;

  @override
  void initState() {
    super.initState();
    _loadSubmittedCases();
  }

  Future<void> _loadSubmittedCases() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _dbRef
          .child('pendingCases')
          .child(widget.groupId)
          .child(user.uid)
          .get();

      final List<Map<String, dynamic>> cases = [];
      if (snapshot.exists) {
        for (var element in snapshot.children) {
          cases.add({
            'id': element.key,
            ...Map<String, dynamic>.from(element.value as Map),
          });
        }
      }

      setState(() {
        _submittedCases = cases;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchPatients(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final snapshot = await _dbRef.child('users').get();
      if (snapshot.exists) {
        final allUsers = snapshot.value as Map<dynamic, dynamic>;
        final results = <Map<String, dynamic>>[];

        allUsers.forEach((userId, userData) {
          final user = Map<String, dynamic>.from(userData as Map);
          final fullName = user['fullName']?.toString() ?? '';
          final idNumber = user['idNumber']?.toString() ?? '';
          final studentId = user['studentId']?.toString() ?? '';

          if (fullName.toLowerCase().contains(query.toLowerCase()) ||
              idNumber.contains(query) ||
              studentId.contains(query)) {
            results.add({'id': userId, ...user});
          }
        });

        setState(() => _searchResults = results);
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _selectPatient(Map<String, dynamic> patient) {
    setState(() {
      _selectedPatient = patient;
      _searchController.clear();
      _searchResults = [];
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPatient = null;
    });
  }

  void _addNewCase(int caseNumber) {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار مريض أولاً')),
      );
      return;
    }

    Widget formScreen;

    switch (widget.courseId) {
      case '080114141': // كورس الجراحة
        formScreen = _SurgeryCaseForm(
          groupId: widget.groupId,
          courseId: widget.courseId,
          caseNumber: caseNumber,
          patient: _selectedPatient!,
          onSave: _loadSubmittedCases,
        );
        break;
      case '080114142': // كورس الباطنة
        formScreen = _InternalMedicineCaseForm(
          groupId: widget.groupId,
          courseId: widget.courseId,
          caseNumber: caseNumber,
          patient: _selectedPatient!,
          onSave: _loadSubmittedCases,
        );
        break;
      case '080114143': // كورس الأطفال
        formScreen = _PediatricsCaseForm(
          groupId: widget.groupId,
          courseId: widget.courseId,
          caseNumber: caseNumber,
          patient: _selectedPatient!,
          onSave: _loadSubmittedCases,
        );
        break;
      default:
        formScreen = _DefaultCaseForm(
          groupId: widget.groupId,
          courseId: widget.courseId,
          caseNumber: caseNumber,
          patient: _selectedPatient!,
          onSave: _loadSubmittedCases,
        );
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => formScreen),
    ).then((_) {
      _clearSelection();
    });
  }

  void _viewCaseDetails(Map<String, dynamic> caseData) {
    Widget detailsScreen;

    switch (widget.courseId) {
      case '080114141':
        detailsScreen = _SurgeryCaseDetails(caseData: caseData);
        break;
      case '080114142':
        detailsScreen = _InternalMedicineCaseDetails(caseData: caseData);
        break;
      case '080114143':
        detailsScreen = _PediatricsCaseDetails(caseData: caseData);
        break;
      default:
        detailsScreen = _DefaultCaseDetails(caseData: caseData);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => detailsScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingCases = widget.requiredCases - _submittedCases.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
      ),
      body: Column(
        children: [
          // شريط البحث عن المرضى
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'ابحث عن مريض (بالاسم أو رقم الهوية)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _isSearching ? const CircularProgressIndicator() : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: _searchPatients,
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    height: 200,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final patient = _searchResults[index];
                        return ListTile(
                          title: Text(patient['fullName'] ?? 'غير معروف'),
                          subtitle: Text(
                              'هوية: ${patient['idNumber'] ?? 'غير معروف'} - جامعي: ${patient['studentId'] ?? 'غير معروف'}'),
                          onTap: () => _selectPatient(patient),
                        );
                      },
                    ),
                  ),
                if (_selectedPatient != null)
                  Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المريض المختار:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                Text(_selectedPatient!['fullName'] ?? ''),
                                Text(
                                    'هوية: ${_selectedPatient!['idNumber'] ?? 'غير معروف'}'),
                                if (_selectedPatient!['studentId'] != null)
                                  Text(
                                      'جامعي: ${_selectedPatient!['studentId']}'),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSelection,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // عرض عدد الحالات المطلوبة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'الحالات المطلوبة: ${widget.requiredCases}',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          // عرض بطاقات الحالات
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: widget.requiredCases,
                    itemBuilder: (context, index) {
                      if (index < _submittedCases.length) {
                        return _buildSubmittedCaseCard(_submittedCases[index]);
                      } else {
                        return _buildEmptyCaseCard(
                            index - _submittedCases.length + 1, remainingCases);
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedCaseCard(Map<String, dynamic> caseData) {
    return Card(
      elevation: 3,
      color: Colors.blue[50],
      child: InkWell(
        onTap: () => _viewCaseDetails(caseData),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.assignment, size: 40, color: Colors.blue),
              const SizedBox(height: 8),
              Text(
                'الحالة ${caseData['caseNumber']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('الحالة: مكتملة',
                  style: TextStyle(color: Colors.green)),
              if (caseData['patientName'] != null)
                Text('المريض: ${caseData['patientName']}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCaseCard(int caseNumber, int remainingCases) {
    return Card(
      elevation: 2,
      color: remainingCases > 0 ? Colors.grey[100] : Colors.green[50],
      child: InkWell(
        onTap: remainingCases > 0 ? () => _addNewCase(caseNumber) : null,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                remainingCases > 0
                    ? Icons.add_circle_outline
                    : Icons.check_circle,
                size: 40,
                color: remainingCases > 0 ? Colors.grey : Colors.green,
              ),
              const SizedBox(height: 8),
              Text(
                'الحالة $caseNumber',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                remainingCases > 0 ? 'غير مكتملة' : 'مكتملة',
                style: TextStyle(
                  color: remainingCases > 0 ? Colors.grey : Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurgeryCaseForm extends StatefulWidget {
  final String groupId;
  final String courseId;
  final int caseNumber;
  final Map<String, dynamic> patient;
  final Function() onSave;

  const _SurgeryCaseForm({
    required this.groupId,
    required this.courseId,
    required this.caseNumber,
    required this.patient,
    required this.onSave,
  });

  @override
  State<_SurgeryCaseForm> createState() => _SurgeryCaseFormState();
}

class _SurgeryCaseFormState extends State<_SurgeryCaseForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _surgeryTypeController = TextEditingController();
  final TextEditingController _anesthesiaTypeController =
      TextEditingController();
  final TextEditingController _procedureController = TextEditingController();

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newCase = {
        'caseNumber': widget.caseNumber,
        'patientName': widget.patient['fullName'],
        'patientId': widget.patient['id'],
        'patientDetails': {
          'idNumber': widget.patient['idNumber'],
          'studentId': widget.patient['studentId'],
          'phone': widget.patient['phone'],
        },
        'diagnosis': _diagnosisController.text,
        'surgeryType': _surgeryTypeController.text,
        'anesthesiaType': _anesthesiaTypeController.text,
        'procedure': _procedureController.text,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'courseId': widget.courseId,
        'submittedAt': ServerValue.timestamp,
        'status': 'pending',
      };

      await FirebaseDatabase.instance
          .ref()
          .child('pendingCases')
          .child(widget.groupId)
          .child(user.uid)
          .push()
          .set(newCase);

      if (!mounted) return;
      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('حالة جراحية ${widget.caseNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
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
                      Text('الاسم: ${widget.patient['fullName']}'),
                      Text('رقم الهوية: ${widget.patient['idNumber']}'),
                      if (widget.patient['studentId'] != null)
                        Text('الرقم الجامعي: ${widget.patient['studentId']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // حقول النموذج
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: 'التشخيص',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _surgeryTypeController,
                decoration: const InputDecoration(
                  labelText: 'نوع الجراحة',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _anesthesiaTypeController,
                decoration: const InputDecoration(
                  labelText: 'نوع التخدير',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _procedureController,
                decoration: const InputDecoration(
                  labelText: 'الإجراء الجراحي',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  child: const Text('حفظ الحالة الجراحية'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InternalMedicineCaseForm extends StatefulWidget {
  final String groupId;
  final String courseId;
  final int caseNumber;
  final Map<String, dynamic> patient;
  final Function() onSave;

  const _InternalMedicineCaseForm({
    required this.groupId,
    required this.courseId,
    required this.caseNumber,
    required this.patient,
    required this.onSave,
  });

  @override
  State<_InternalMedicineCaseForm> createState() =>
      _InternalMedicineCaseFormState();
}

class _InternalMedicineCaseFormState extends State<_InternalMedicineCaseForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _historyController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _labResultsController = TextEditingController();

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newCase = {
        'caseNumber': widget.caseNumber,
        'patientName': widget.patient['fullName'],
        'patientId': widget.patient['id'],
        'patientDetails': {
          'idNumber': widget.patient['idNumber'],
          'studentId': widget.patient['studentId'],
          'phone': widget.patient['phone'],
        },
        'diagnosis': _diagnosisController.text,
        'history': _historyController.text,
        'medications': _medicationsController.text,
        'labResults': _labResultsController.text,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'courseId': widget.courseId,
        'submittedAt': ServerValue.timestamp,
        'status': 'pending',
      };

      await FirebaseDatabase.instance
          .ref()
          .child('pendingCases')
          .child(widget.groupId)
          .child(user.uid)
          .push()
          .set(newCase);

      if (!mounted) return;
      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('حالة باطنية ${widget.caseNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
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
                      Text('الاسم: ${widget.patient['fullName']}'),
                      Text('رقم الهوية: ${widget.patient['idNumber']}'),
                      if (widget.patient['studentId'] != null)
                        Text('الرقم الجامعي: ${widget.patient['studentId']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // حقول النموذج
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: 'التشخيص',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _historyController,
                decoration: const InputDecoration(
                  labelText: 'التاريخ المرضي',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _medicationsController,
                decoration: const InputDecoration(
                  labelText: 'الأدوية الموصوفة',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _labResultsController,
                decoration: const InputDecoration(
                  labelText: 'نتائج المختبر',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  child: const Text('حفظ الحالة الباطنية'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PediatricsCaseForm extends StatefulWidget {
  final String groupId;
  final String courseId;
  final int caseNumber;
  final Map<String, dynamic> patient;
  final Function() onSave;

  const _PediatricsCaseForm({
    required this.groupId,
    required this.courseId,
    required this.caseNumber,
    required this.patient,
    required this.onSave,
  });

  @override
  State<_PediatricsCaseForm> createState() => _PediatricsCaseFormState();
}

class _PediatricsCaseFormState extends State<_PediatricsCaseForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _vaccinationController = TextEditingController();
  final TextEditingController _growthController = TextEditingController();

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newCase = {
        'caseNumber': widget.caseNumber,
        'patientName': widget.patient['fullName'],
        'patientId': widget.patient['id'],
        'patientDetails': {
          'idNumber': widget.patient['idNumber'],
          'studentId': widget.patient['studentId'],
          'phone': widget.patient['phone'],
        },
        'diagnosis': _diagnosisController.text,
        'age': _ageController.text,
        'vaccination': _vaccinationController.text,
        'growth': _growthController.text,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'courseId': widget.courseId,
        'submittedAt': ServerValue.timestamp,
        'status': 'pending',
      };

      await FirebaseDatabase.instance
          .ref()
          .child('pendingCases')
          .child(widget.groupId)
          .child(user.uid)
          .push()
          .set(newCase);

      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('حالة أطفال ${widget.caseNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
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
                      Text('الاسم: ${widget.patient['fullName']}'),
                      Text('رقم الهوية: ${widget.patient['idNumber']}'),
                      if (widget.patient['studentId'] != null)
                        Text('الرقم الجامعي: ${widget.patient['studentId']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // حقول النموذج
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: 'التشخيص',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: 'العمر',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vaccinationController,
                decoration: const InputDecoration(
                  labelText: 'الحالة التطعيمية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _growthController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات النمو',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  child: const Text('حفظ حالة الأطفال'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultCaseForm extends StatefulWidget {
  final String groupId;
  final String courseId;
  final int caseNumber;
  final Map<String, dynamic> patient;
  final Function() onSave;

  const _DefaultCaseForm({
    required this.groupId,
    required this.courseId,
    required this.caseNumber,
    required this.patient,
    required this.onSave,
  });

  @override
  State<_DefaultCaseForm> createState() => _DefaultCaseFormState();
}

class _DefaultCaseFormState extends State<_DefaultCaseForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newCase = {
        'caseNumber': widget.caseNumber,
        'patientName': widget.patient['fullName'],
        'patientId': widget.patient['id'],
        'patientDetails': {
          'idNumber': widget.patient['idNumber'],
          'studentId': widget.patient['studentId'],
          'phone': widget.patient['phone'],
        },
        'diagnosis': _diagnosisController.text,
        'notes': _notesController.text,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'courseId': widget.courseId,
        'submittedAt': ServerValue.timestamp,
        'status': 'pending',
      };

      await FirebaseDatabase.instance
          .ref()
          .child('pendingCases')
          .child(widget.groupId)
          .child(user.uid)
          .push()
          .set(newCase);

      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('حالة عامة ${widget.caseNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
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
                      Text('الاسم: ${widget.patient['fullName']}'),
                      Text('رقم الهوية: ${widget.patient['idNumber']}'),
                      if (widget.patient['studentId'] != null)
                        Text('الرقم الجامعي: ${widget.patient['studentId']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // حقول النموذج
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: 'التشخيص',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات إضافية',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  child: const Text('حفظ الحالة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurgeryCaseDetails extends StatelessWidget {
  final Map<String, dynamic> caseData;

  const _SurgeryCaseDetails({required this.caseData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الحالة الجراحية')),
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
                          Text(
                              'رقم الهوية: ${caseData['patientDetails']['idNumber']}'),
                          if (caseData['patientDetails']['studentId'] != null)
                            Text(
                                'الرقم الجامعي: ${caseData['patientDetails']['studentId']}'),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // تفاصيل الحالة
            _buildDetailItem('التشخيص', caseData['diagnosis']),
            _buildDetailItem('نوع الجراحة', caseData['surgeryType']),
            _buildDetailItem('نوع التخدير', caseData['anesthesiaType']),
            _buildDetailItem('الإجراء الجراحي', caseData['procedure']),
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

class _InternalMedicineCaseDetails extends StatelessWidget {
  final Map<String, dynamic> caseData;

  const _InternalMedicineCaseDetails({required this.caseData});

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
                          Text(
                              'رقم الهوية: ${caseData['patientDetails']['idNumber']}'),
                          if (caseData['patientDetails']['studentId'] != null)
                            Text(
                                'الرقم الجامعي: ${caseData['patientDetails']['studentId']}'),
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

class _PediatricsCaseDetails extends StatelessWidget {
  final Map<String, dynamic> caseData;

  const _PediatricsCaseDetails({required this.caseData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل حالة الأطفال')),
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
                          Text(
                              'رقم الهوية: ${caseData['patientDetails']['idNumber']}'),
                          if (caseData['patientDetails']['studentId'] != null)
                            Text(
                                'الرقم الجامعي: ${caseData['patientDetails']['studentId']}'),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // تفاصيل الحالة
            _buildDetailItem('التشخيص', caseData['diagnosis']),
            _buildDetailItem('العمر', caseData['age']),
            _buildDetailItem('الحالة التطعيمية', caseData['vaccination']),
            _buildDetailItem('ملاحظات النمو', caseData['growth']),
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

class _DefaultCaseDetails extends StatelessWidget {
  final Map<String, dynamic> caseData;

  const _DefaultCaseDetails({required this.caseData});

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
                          Text(
                              'رقم الهوية: ${caseData['patientDetails']['idNumber']}'),
                          if (caseData['patientDetails']['studentId'] != null)
                            Text(
                                'الرقم الجامعي: ${caseData['patientDetails']['studentId']}'),
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
