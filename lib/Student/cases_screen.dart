import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../forms/paedodontics_form.dart';
import '../Student/forms/internal_medicine_case_form.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../dashboard/student_dashboard.dart';

class CasesScreen extends StatefulWidget {
  final String groupId;
  final String courseId;
  final String courseName;
  final int requiredCases;

  const CasesScreen({
    required this.groupId,
    required this.courseId,
    required this.courseName,
    required this.requiredCases,
    Key? key,
  }) : super(key: key);

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _submittedCases = [];
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

      if (widget.courseId == '080114140') {
        final snapshot = await _dbRef
            .child('paedodonticsCases')
            .orderByChild('studentId')
            .equalTo(user.uid)
            .get();
        final List<Map<String, dynamic>> cases = [];
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            cases.add({'id': key, ...Map<String, dynamic>.from(value as Map)});
          });
        }
        setState(() {
          _submittedCases = cases;
        });
      } else {
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
        });
      }
    } catch (e) {
      setState(() {});
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
      final usersSnap = await _dbRef.child('users').get();
      final results = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      if (usersSnap.exists) {
        final allUsers = usersSnap.value as Map<dynamic, dynamic>;
        allUsers.forEach((userId, userData) {
          final user = Map<String, dynamic>.from(userData as Map);
          String fullName = user['fullName']?.toString() ?? '';
          if (fullName.trim().isEmpty) {
            final firstName = user['firstName']?.toString() ?? '';
            final fatherName = user['fatherName']?.toString() ?? '';
            final grandfatherName = user['grandfatherName']?.toString() ?? '';
            final familyName = user['familyName']?.toString() ?? '';
            fullName = [firstName, fatherName, grandfatherName, familyName]
                .where((part) => part.isNotEmpty)
                .join(' ');
          }
          final idNumber = user['idNumber']?.toString() ?? '';
          final studentId = user['studentId']?.toString() ?? '';
          if (fullName.toLowerCase().contains(query.toLowerCase()) ||
              idNumber.contains(query) ||
              studentId.contains(query)) {
            if (!seenIds.contains(idNumber)) {
              results.add({'id': userId, ...user, 'fullName': fullName});
              seenIds.add(idNumber);
            }
          }
        });
      }

      setState(() => _searchResults = results);
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

  List<Map<String, dynamic>> get _paedoCaseList {
    final List<Map<String, dynamic>> cases = [];
    for (int i = 1; i <= 3; i++) {
      cases.add({'type': 'history', 'number': i});
    }
    for (int i = 1; i <= 6; i++) {
      cases.add({'type': 'fissure', 'number': i});
    }
    return cases;
  }

  Map<String, Map<int, Map<String, dynamic>>> get _submittedPaedoCasesByTypeAndNumber {
    final map = <String, Map<int, Map<String, dynamic>>>{};
    for (final c in _submittedCases) {
      final type = c['caseType'] ?? c['type'];
      final number = c['caseNumber'];
      if (type != null && number != null) {
        map[type] ??= {};
        map[type]![number] = c;
      }
    }
    return map;
  }

  void _addNewPaedoCase(String type, int number) {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار مريض أولاً')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaedodonticsForm(
          groupId: widget.groupId,
          caseNumber: number,
          patient: _selectedPatient!,
          courseId: widget.courseId,
          onSave: _loadSubmittedCases,
          caseType: type,
        ),
      ),
    ).then((_) => _clearSelection());
  }

  Widget _buildPaedodonticsCaseCard(
    String type,
    int number,
    Map<String, dynamic>? submitted,
    bool canAdd,
  ) {
    final isCompleted = submitted != null && submitted['status'] == 'graded';
    final isPending = submitted != null && submitted['status'] == 'pending';
    final isRejected = submitted != null && submitted['status'] == 'rejected';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: isCompleted
            ? Colors.blue[50]
            : isPending
                ? Colors.orange[50]
                : isRejected
                    ? Colors.red[50]
                    : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: (isCompleted || isPending || isRejected)
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaedodonticsForm(
                        groupId: widget.groupId,
                        caseNumber: number,
                        patient: submitted['patient'] != null
                            ? Map<String, dynamic>.from(submitted['patient'])
                            : {},
                        courseId: widget.courseId,
                        onSave: _loadSubmittedCases,
                        caseType: type,
                        initialData: submitted,
                      ),
                    ),
                  );
                }
              : canAdd
                  ? () => _addNewPaedoCase(type, number)
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يجب إكمال الحالة السابقة أولاً')),
                      );
                    },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.assignment_turned_in
                      : isPending
                          ? Icons.hourglass_top
                          : isRejected
                              ? Icons.cancel
                              : Icons.assignment,
                  size: 40,
                  color: isCompleted
                      ? Colors.green
                      : isPending
                          ? Colors.orange
                          : isRejected
                              ? Colors.red
                              : Colors.grey,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              type == 'history'
                                  ? 'حالة تاريخ وفحص #$number'
                                  : 'حالة سد شقوق #$number',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (isCompleted && submitted['doctorGrade'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.grade,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${submitted['doctorGrade']}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCompleted
                            ? 'مكتملة'
                            : isPending
                                ? 'قيد المراجعة'
                                : isRejected
                                    ? 'مرفوضة'
                                    : 'غير مكتملة',
                        style: TextStyle(
                          color: isCompleted
                              ? Colors.green
                              : isPending
                                  ? Colors.orange
                                  : isRejected
                                      ? Colors.red
                                      : Colors.grey,
                        ),
                      ),
                      if (submitted != null && submitted['patientName'] != null)
                        Text('المريض: ${submitted['patientName']}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width >= 900;
    return Directionality(
      textDirection: Provider.of<LanguageProvider>(context, listen: false)
          .currentLocale
          .languageCode ==
          'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.courseName,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: primaryColor,
          centerTitle: true,
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: primaryColor),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment, size: 48, color: Colors.white),
                    const SizedBox(height: 10),
                    Text('حالات الطالب',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.home, color: primaryColor),
                title: const Text('الرئيسية'),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const StudentDashboard()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
        endDrawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: primaryColor),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment, size: 48, color: Colors.white),
                    const SizedBox(height: 10),
                    Text('حالات الطالب',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.home, color: primaryColor),
                title: const Text('الرئيسية'),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const StudentDashboard()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
        body: _buildResponsiveBody(context, isLargeScreen),
      ),
    );
  }

  Widget _buildResponsiveBody(BuildContext context, bool isLargeScreen) {
    if (widget.courseId == '080114140') {
      final paedoCases = _paedoCaseList;
      final submittedMap = _submittedPaedoCasesByTypeAndNumber;
      return Row(
        children: [
          if (isLargeScreen)
            Container(
              width: 250,
              color: primaryColor.withOpacity(0.08),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Icon(Icons.assignment, size: 48, color: primaryColor),
                  const SizedBox(height: 10),
                  Text('حالات الطالب',
                      style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.home, color: primaryColor),
                    title: const Text('الرئيسية'),
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const StudentDashboard()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'ابحث عن مريض (بالاسم أو رقم الهوية)',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _isSearching
                              ? const CircularProgressIndicator()
                              : null,
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
                                      Text('المريض المختار:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor)),
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
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: paedoCases.length,
                    itemBuilder: (context, index) {
                      final item = paedoCases[index];
                      final type = item['type'] as String;
                      final number = item['number'] as int;
                      final submitted = submittedMap[type]?[number];
                      bool canAdd = false;

                      if (submitted == null ||
                          (submitted['status'] != 'graded' &&
                              submitted['status'] != 'pending')) {
                        if (index == 0) {
                          canAdd = true;
                        } else {
                          final prev = paedoCases[index - 1];
                          final prevType = prev['type'] as String;
                          final prevNumber = prev['number'] as int;
                          final prevSubmitted = submittedMap[prevType]?[prevNumber];
                          canAdd = prevSubmitted != null &&
                              prevSubmitted['status'] == 'graded';
                        }
                      }

                      return _buildPaedodonticsCaseCard(
                        type,
                        number,
                        submitted,
                        canAdd,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (widget.courseId == '080114141') {
      return InternalMedicineCaseForm(
        groupId: widget.groupId,
        courseId: widget.courseId,
        caseNumber: 1,
        patient: _selectedPatient ?? {},
        onSave: _loadSubmittedCases,
      );
    }
    // Add other course-specific screens here
    return Scaffold(
      appBar: AppBar(title: Text(widget.courseName)),
      body: const Center(child: Text('لا يوجد نموذج مخصص لهذه المادة')),
    );
  }
}
