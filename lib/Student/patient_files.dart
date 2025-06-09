import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../dashboard/student_dashboard.dart';

class PatientFilesPage extends StatefulWidget {
  const PatientFilesPage({super.key});

  @override
  State<PatientFilesPage> createState() => _PatientFilesPageState();
}

class _PatientFilesPageState extends State<PatientFilesPage> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  late DatabaseReference _usersRef;
  late DatabaseReference _waitingListRef;

  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  List<Map<String, dynamic>> waitingList = [];
  List<Map<String, dynamic>> filteredWaitingList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // أضف الترجمة الجديدة
  final Map<String, Map<String, String>> _translations = {
    'patient_files': {'ar': 'ملفات المرضى', 'en': 'Patient Files'},
    'waiting_list': {'ar': 'قائمة الانتظار', 'en': 'Waiting List'},
    'all_patients': {'ar': 'جميع المرضى', 'en': 'All Patients'},
    'name': {'ar': 'الاسم', 'en': 'Name'},
    'phone': {'ar': 'الهاتف', 'en': 'Phone'},
    'age': {'ar': 'العمر', 'en': 'Age'},
    'add_to_waiting_list': {'ar': 'إضافة للانتظار', 'en': 'Add to Waiting List'},
    'remove_from_waiting_list': {'ar': 'إزالة من الانتظار', 'en': 'Remove from Waiting List'},
    'no_patients': {'ar': 'لا يوجد مرضى', 'en': 'No patients found'},
    'error_loading': {'ar': 'خطأ في تحميل البيانات', 'en': 'Error loading data'},
    'retry': {'ar': 'إعادة المحاولة', 'en': 'Retry'},
    'age_unknown': {'ar': 'العمر غير معروف', 'en': 'Age unknown'},
    'next_step': {'ar': 'الخطوة التالية', 'en': 'Next Step'},
    'search_hint': {'ar': 'ابحث بالاسم أو رقم الهوية...', 'en': 'Search by name or ID...'},
    'already_in_waiting_list': {'ar': 'المريض موجود بالفعل في قائمة الانتظار', 'en': 'Patient is already in the waiting list'},
  };

  @override
  void initState() {
    super.initState();
    _initializeReferences();
    _loadData();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeReferences() {
    _usersRef = FirebaseDatabase.instance.ref('users');
    _waitingListRef = FirebaseDatabase.instance.ref('waitingList');
  }

  Future<void> _loadData() async {
    try {
      final usersSnapshot = await _usersRef.get();
      final waitingSnapshot = await _waitingListRef.get();

      setState(() {
        allUsers = _parseUsersSnapshot(usersSnapshot);
        filteredUsers = List.from(allUsers);
        waitingList = _parseWaitingSnapshot(waitingSnapshot);
        filteredWaitingList = List.from(waitingList);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _parseUsersSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) return [];

    final List<Map<String, dynamic>> result = [];
    final data = snapshot.value as Map<dynamic, dynamic>? ?? {};

    data.forEach((key, value) {
      if (value is Map<dynamic, dynamic>) {
        final userData = Map<String, dynamic>.from(value);
        userData['id'] = key.toString();
        result.add(userData);
      }
    });

    return result;
  }

  List<Map<String, dynamic>> _parseWaitingSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) return [];

    final List<Map<String, dynamic>> result = [];
    final data = snapshot.value as Map<dynamic, dynamic>? ?? {};

    data.forEach((key, value) {
      if (value is Map<dynamic, dynamic>) {
        final waitingData = Map<String, dynamic>.from(value);
        waitingData['id'] = key.toString();
        result.add(waitingData);
      }
    });

    return result;
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      filteredUsers = allUsers.where((user) {
        final fullName = _getFullName(user).toLowerCase();
        final userId = user['id']?.toString().toLowerCase() ?? '';
        final phone = user['phone']?.toString().toLowerCase() ?? '';

        return fullName.contains(query) ||
            userId.contains(query) ||
            phone.contains(query);
      }).toList();

      filteredWaitingList = waitingList.where((user) {
        final name = user['name']?.toString().toLowerCase() ?? '';
        final userId = user['id']?.toString().toLowerCase() ?? '';
        final phone = user['phone']?.toString().toLowerCase() ?? '';

        return name.contains(query) ||
            userId.contains(query) ||
            phone.contains(query);
      }).toList();
    });
  }

  DateTime? _parseBirthDate(dynamic birthDateValue) {
    try {
      if (birthDateValue == null) return null;

      final birthDateMillis = birthDateValue is String
          ? int.tryParse(birthDateValue) ?? 0
          : birthDateValue is int
          ? birthDateValue
          : 0;

      if (birthDateMillis <= 0) return null;

      return DateTime.fromMillisecondsSinceEpoch(birthDateMillis);
    } catch (e) {
      debugPrint('Error parsing birth date: $e');
      return null;
    }
  }

  int _calculateAgeFromDate(DateTime birthDate) {
    final currentDate = DateTime.now();
    int age = currentDate.year - birthDate.year;

    if (currentDate.month < birthDate.month ||
        (currentDate.month == birthDate.month &&
            currentDate.day < birthDate.day)) {
      age--;
    }

    return age >= 0 ? age : 0;
  }

  String _formatAge(BuildContext context, dynamic birthDateValue) {
    final birthDate = _parseBirthDate(birthDateValue);
    if (birthDate == null) return _translate(context, 'age_unknown');

    final age = _calculateAgeFromDate(birthDate);
    return '$age ${_translate(context, 'age')}';
  }

  String _translate(BuildContext context, String key) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return _translations[key]![languageProvider.currentLocale.languageCode] ?? '';
  }

  String _getFullName(Map<String, dynamic> user) {
    final firstName = user['firstName']?.toString().trim() ?? '';
    final fatherName = user['fatherName']?.toString().trim() ?? '';
    final grandfatherName = user['grandfatherName']?.toString().trim() ?? '';
    final familyName = user['familyName']?.toString().trim() ?? '';

    return [
      if (firstName.isNotEmpty) firstName,
      if (fatherName.isNotEmpty) fatherName,
      if (grandfatherName.isNotEmpty) grandfatherName,
      if (familyName.isNotEmpty) familyName,
    ].join(' ');
  }

  void _addToWaitingList(Map<String, dynamic> user) async {
    // تحقق إذا كان المريض موجود بالفعل في قائمة الانتظار
    final alreadyExists = waitingList.any((item) => item['userId'] == user['id']);
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translate(context, 'already_in_waiting_list'))),
      );
      return;
    }
    try {
      await _waitingListRef.push().set({
        'userId': user['id'],
        'name': _getFullName(user),
        'phone': user['phone'] ?? '',
        'addedAt': DateTime.now().toIso8601String(),
      });
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translate(context, 'add_to_waiting_list') + ' ✔️')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء الإضافة: $e')),
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(_translate(context, 'patient_files'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    Icon(Icons.folder_shared, size: 48, color: Colors.white),
                    const SizedBox(height: 10),
                    Text('ملفات المرضى', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                    Icon(Icons.folder_shared, size: 48, color: Colors.white),
                    const SizedBox(height: 10),
                    Text('ملفات المرضى', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                          Icon(Icons.folder_shared, size: 48, color: primaryColor),
                          const SizedBox(height: 10),
                          Text('ملفات المرضى', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: _translate(context, 'search_hint'),
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: (value) => _filterUsers(),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView(
                              children: [
                                Text(_translate(context, 'all_patients'), style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                                const SizedBox(height: 8),
                                ...filteredUsers.map((user) => Card(
                                      color: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: accentColor,
                                          child: Icon(Icons.person, color: Colors.white),
                                        ),
                                        title: Text(_getFullName(user), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                        subtitle: Text('${_translate(context, 'age')}: ${_formatAge(context, user['birthDate'])}'),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.add, color: Colors.green),
                                          onPressed: () {
                                            _addToWaitingList(user);
                                          },
                                        ),
                                      ),
                                    )),
                                const SizedBox(height: 24),
                                Text(_translate(context, 'waiting_list'), style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                                const SizedBox(height: 8),
                                ...filteredWaitingList.map((user) => Card(
                                      color: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.orange,
                                          child: Icon(Icons.timer, color: Colors.white),
                                        ),
                                        title: Text(user['name'] ?? '', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                        subtitle: Text('${_translate(context, 'phone')}: ${user['phone'] ?? ''}'),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                          onPressed: () {
                                            // Remove from waiting list logic
                                          },
                                        ),
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}