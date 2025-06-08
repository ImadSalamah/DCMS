import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cases_screen.dart';
import '../dashboard/student_dashboard.dart';

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
        });
      }
    } catch (e) {
      setState(() {});
    }
  }

  void _navigateToLogbook(BuildContext context, Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CasesScreen(
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
    final Color primaryColor = const Color(0xFF2A7A94);
    final Color accentColor = const Color(0xFF4AB8D8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('شعبي الدراسية', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  Icon(Icons.groups, size: 48, color: Colors.white),
                  const SizedBox(height: 10),
                  Text('مجموعات الطالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                  Icon(Icons.groups, size: 48, color: Colors.white),
                  const SizedBox(height: 10),
                  Text('مجموعات الطالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
      body: _studentGroups.isEmpty
          ? const Center(child: Text('لا توجد شعب مسجلة لك'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _studentGroups.length,
              itemBuilder: (context, index) {
                final group = _studentGroups[index];
                return Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: accentColor,
                      child: Icon(Icons.group, color: Colors.white),
                    ),
                    title: Text(group['courseName'], style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                    subtitle: Text('الشعبة ${group['groupNumber']}', style: TextStyle(color: Colors.grey[700])),
                    trailing: const Icon(Icons.arrow_forward, color: Colors.grey),
                    onTap: () => _navigateToLogbook(context, group),
                  ),
                ); // Missing closing parenthesis fixed
              },
            ),
    );
  }
}