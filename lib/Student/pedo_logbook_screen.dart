import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../providers/language_provider.dart';
import './history_case_form_screen.dart';
import './fissure_sealant_form_screen.dart';
import './history_case_details_screen.dart';
import './fissure_sealant_details_screen.dart';
import './evaluate_case_screen.dart';
import '../dashboard/student_dashboard.dart';

class PedoLogbookScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String groupId;
  final String courseName;
  final String courseNumber;

  const PedoLogbookScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.groupId,
    required this.courseName,
    required this.courseNumber,
  });

  @override
  State<PedoLogbookScreen> createState() => _PedoLogbookScreenState();
}

class _PedoLogbookScreenState extends State<PedoLogbookScreen> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _pendingCases = [];
  List<Map<String, dynamic>> _completedCases = [];
  bool _isLoading = true;
  bool _isDoctor = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadCases();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await _dbRef.child('users/${user.uid}/role').get();
      setState(() => _isDoctor = snapshot.value == 'doctor');
    }
  }

  Future<void> _loadCases() async {
    try {
      final historySnapshot = await _dbRef
          .child('logbookEntries')
          .child(widget.groupId)
          .child(widget.studentId)
          .child('historyCases')
          .get();

      final sealantSnapshot = await _dbRef
          .child('logbookEntries')
          .child(widget.groupId)
          .child(widget.studentId)
          .child('sealantCases')
          .get();

      final List<Map<String, dynamic>> allCases = [];

      if (historySnapshot.exists) {
        historySnapshot.children.forEach((element) {
          allCases.add({
            'type': 'history',
            'id': element.key,
            ...Map<String, dynamic>.from(element.value as Map),
          });
        });
      }

      if (sealantSnapshot.exists) {
        sealantSnapshot.children.forEach((element) {
          allCases.add({
            'type': 'sealant',
            'id': element.key,
            ...Map<String, dynamic>.from(element.value as Map),
          });
        });
      }

      setState(() {
        _pendingCases = allCases.where((c) => c['status'] != 'completed').toList();
        _completedCases = allCases.where((c) => c['status'] == 'completed').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _addNewCase(String type) {
    if (type == 'history') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryCaseFormScreen(
            studentId: widget.studentId,
            studentName: widget.studentName,
            groupId: widget.groupId,
            onSave: _loadCases,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FissureSealantFormScreen(
            studentId: widget.studentId,
            studentName: widget.studentName,
            groupId: widget.groupId,
            onSave: _loadCases,
          ),
        ),
      );
    }
  }

  void _viewCaseDetails(Map<String, dynamic> caseData) {
    if (_isDoctor && caseData['status'] != 'completed') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EvaluateCaseScreen(
            groupId: widget.groupId,
            studentId: widget.studentId,
            caseId: caseData['id'],
            caseType: caseData['type'],
            caseData: caseData,
            onEvaluate: _loadCases,
          ),
        ),
      );
    } else if (caseData['type'] == 'history') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryCaseDetailsScreen(
            caseData: caseData,
            isViewOnly: true,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FissureSealantDetailsScreen(
            caseData: caseData,
            isViewOnly: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width >= 900;
    return Directionality(
      textDirection: Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.courseName, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: primaryColor,
            centerTitle: true,
            bottom: const TabBar(
              tabs: [
                Tab(text: 'المطلوبة'),
                Tab(text: 'المكتملة'),
              ],
            ),
            actions: [
              if (!_isDoctor && widget.courseNumber == '080114140')
                PopupMenuButton<String>(
                  onSelected: _addNewCase,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'history',
                      child: Text('إضافة حالة تاريخ وفحص'),
                    ),
                    const PopupMenuItem(
                      value: 'sealant',
                      child: Text('إضافة حالة حشوة شقوق'),
                    ),
                  ],
                ),
            ],
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
                      Text('سجل الطالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                      Text('سجل الطالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
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
                            Text('سجل الطالب', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
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
                      child: TabBarView(
                        children: [
                          _buildCasesList(_pendingCases),
                          _buildCasesList(_completedCases),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCasesList(List<Map<String, dynamic>> cases) {
    if (cases.isEmpty) {
      return const Center(child: Text('لا توجد حالات'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: cases.length,
      itemBuilder: (context, index) {
        final caseData = cases[index];
        final isHistory = caseData['type'] == 'history';
        final isCompleted = caseData['status'] == 'completed';
        final title = isHistory ? 'حالة التاريخ والفحص' : 'حالة حشوة الشقوق';
        final icon = isHistory ? Icons.assignment : Icons.medical_services;
        final maxScore = isHistory ? 35 : 35;
        final score = caseData['score'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: isCompleted ? Colors.grey[100] : null,
          child: ListTile(
            leading: Icon(icon, color: isCompleted ? Colors.green : Colors.blue),
            title: Text(title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اسم المريض: ${caseData['patientName'] ?? 'غير معروف'}'),
                if (caseData['date'] != null) Text('التاريخ: ${caseData['date']}'),
                if (!isHistory) Text('الأسنان: ${caseData['teeth'] ?? 'غير معروف'}'),
                if (isCompleted) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: score / maxScore,
                    backgroundColor: Colors.grey[300],
                    color: score >= maxScore * 0.7 ? Colors.green : Colors.orange,
                  ),
                  Text('الدرجة: $score/$maxScore'),
                ],
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _viewCaseDetails(caseData),
          ),
        );
      },
    );
  }
}