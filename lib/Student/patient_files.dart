import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

class PatientFilesPage extends StatefulWidget {
  const PatientFilesPage({super.key});

  @override
  State<PatientFilesPage> createState() => _PatientFilesPageState();
}

class _PatientFilesPageState extends State<PatientFilesPage> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _usersRef;
  late DatabaseReference _waitingListRef;

  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  List<Map<String, dynamic>> waitingList = [];
  List<Map<String, dynamic>> filteredWaitingList = [];
  bool _isLoading = true;
  bool _hasError = false;
  final TextEditingController _searchController = TextEditingController();

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
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
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

  bool _isArabic(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return languageProvider.currentLocale.languageCode == 'ar';
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

  Future<void> _addToWaitingList(String userId, Map<String, dynamic> userData) async {
    try {
      final birthDate = _parseBirthDate(userData['birthDate']);
      final age = birthDate != null ? _calculateAgeFromDate(birthDate) : 0;

      await _waitingListRef.child(userId).set({
        'name': _getFullName(userData),
        'phone': userData['phone'] ?? '',
        'age': age,
        'timestamp': ServerValue.timestamp,
      });

      setState(() {
        waitingList.add({
          'id': userId,
          'name': _getFullName(userData),
          'phone': userData['phone'] ?? '',
          'age': age,
        });
        filteredWaitingList = List.from(waitingList);
      });
    } catch (e) {
      debugPrint('Error adding to waiting list: $e');
    }
  }

  Future<void> _removeFromWaitingList(String userId) async {
    try {
      final user = waitingList.firstWhere((u) => u['id'] == userId);
      await _waitingListRef.child(userId).remove();

      setState(() {
        waitingList.removeWhere((user) => user['id'] == userId);
        filteredWaitingList = List.from(waitingList);
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_translate(context, 'remove_from_waiting_list')} ${user['name']}'),
            backgroundColor: Colors.orange,
          )
      );
    } catch (e) {
      debugPrint('Error removing from waiting list: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_translate(context, 'error_loading')),
            backgroundColor: Colors.red,
          )
      );
    }
  }

  bool _isInWaitingList(String userId) {
    return waitingList.any((user) => user['id'] == userId);
  }

  Widget _buildPatientCard(Map<String, dynamic> user, BuildContext context) {
    final isInWaitingList = _isInWaitingList(user['id']);
    final fullName = _getFullName(user);
    final phone = user['phone']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ID: ${user['idNumber']}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Icon(
                  Icons.person,
                  color: primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(phone),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.cake, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(_formatAge(context, user['birthDate'])),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton(
                onPressed: () {
                  if (isInWaitingList) {
                    _removeFromWaitingList(user['id']);
                  } else {
                    _addToWaitingList(user['id'], user);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isInWaitingList ? Colors.red : primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  isInWaitingList
                      ? _translate(context, 'remove_from_waiting_list')
                      : _translate(context, 'add_to_waiting_list'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingListCard(Map<String, dynamic> user, BuildContext context) {
    final fullName = user['name']?.toString() ?? '';
    final phone = user['phone']?.toString() ?? '';
    final age = user['age'] is int ? user['age'] : 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ID: ${user['id']}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Icon(
                  Icons.access_time,
                  color: primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(phone),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.cake, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(age > 0 ? '$age ${_translate(context, 'age')}' : _translate(context, 'age_unknown')),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton(
                onPressed: () {
                  // سيتم إضافة وظيفة النقل لمكان آخر لاحقًا
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  _translate(context, 'next_step'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 50, color: Colors.red),
          const SizedBox(height: 20),
          Text(
            _translate(context, 'error_loading'),
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              _translate(context, 'retry'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: _translate(context, 'search_hint'),
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey[200],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_translate(context, 'patient_files')),
        backgroundColor: primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? _buildErrorWidget()
          : Column(
        children: [
          _buildSearchField(context),
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(child: Text(_translate(context, 'no_patients')))
                : ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                return _buildPatientCard(filteredUsers[index], context);
              },
            ),
          ),
        ],
      ),
    );
  }
}