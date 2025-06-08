import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../forms/paedodontics_form.dart';
import '../dashboard/student_dashboard.dart'; // Import the StudentDashboard

class PedoStudentCasesPage extends StatefulWidget {
  final String? courseId; // Pass courseId for generic use
  const PedoStudentCasesPage({super.key, this.courseId});

  @override
  State<PedoStudentCasesPage> createState() => _PedoStudentCasesPageState();
}

class _PedoStudentCasesPageState extends State<PedoStudentCasesPage> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
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
    // TODO: Replace these with actual values from your app context or selection
    final String groupId = 'REPLACE_WITH_GROUP_ID'; // e.g., from user/group selection
    final int caseNumber = 1; // e.g., from case selection logic
    final Map<String, dynamic> patient = {}; // e.g., from patient selection
    final String courseId = _courseId ?? '080114140';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaedodonticsForm(
          groupId: groupId,
          caseNumber: caseNumber,
          patient: patient,
          courseId: courseId,
          onSave: _loadRequirementsAndProgress,
          caseType: type,
        ),
      ),
    );
    _loadRequirementsAndProgress();
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width >= 900;
    return Directionality(
      textDirection: Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الحالات المطلوبة', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    Text('حالات الطالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                    Text('حالات الطالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                          Text('حالات الطالب', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
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
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requiredCases.length,
                      itemBuilder: (context, index) {
                        final item = _requiredCases[index];
                        final completed = _completedCases[item['type']] ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          color: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(item['title'], style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                            subtitle: Text('المطلوب: ${item['required']} | المنجز: $completed', style: TextStyle(color: Colors.grey[700])),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: completed < (item['required'] as int)
                                  ? () => _openForm(context, item['type'])
                                  : null,
                              child: const Text('عَبِّئ الحالة'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
