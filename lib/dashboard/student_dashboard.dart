import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/language_provider.dart';
import '../loginpage.dart';
import '../Student/student_groups_page.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _userRef;
  late DatabaseReference _notificationsRef;

  String _userName = '';
  String _userImageUrl = '';
  List<Map<String, dynamic>> assignedPatients = [];
  List<Map<String, dynamic>> notifications = [];
  bool _isLoading = true;
  bool _hasError = false;
  final int _retryCount = 0;
  final int _maxRetries = 3;

  final Map<String, Map<String, String>> _translations = {
    'student_dashboard': {'ar': 'لوحة الطالب', 'en': 'Student Dashboard'},
    'view_examinations': {'ar': 'عرض الفحوصات', 'en': 'View Examinations'},
    'examine_patient': {'ar': 'فحص المريض', 'en': 'Examine Patient'},
    'notifications': {'ar': 'الإشعارات', 'en': 'Notifications'},
    'student': {'ar': 'طالب', 'en': 'Student'},
    'home': {'ar': 'الرئيسية', 'en': 'Home'},
    'settings': {'ar': 'الإعدادات', 'en': 'Settings'},
    'app_name': {
      'ar': 'عيادات أسنان الجامعة العربية الأمريكية',
      'en': 'Arab American University Dental Clinics'
    },
    'error_loading_data': {
      'ar': 'حدث خطأ في تحميل البيانات',
      'en': 'Error loading data'
    },
    'retry': {'ar': 'إعادة المحاولة', 'en': 'Retry'},
    'no_internet': {
      'ar': 'لا يوجد اتصال بالإنترنت',
      'en': 'No internet connection'
    },
    'server_error': {'ar': 'خطأ في السيرفر', 'en': 'Server error'},
    'no_notifications': {'ar': 'لا توجد إشعارات', 'en': 'No notifications'},
    'close': {'ar': 'إغلاق', 'en': 'Close'},
  };

  @override
  void initState() {
    super.initState();
    _initializeReferences();
    _setupRealtimeListener();
    _loadData();
  }

  void _initializeReferences() {
    final user = _auth.currentUser;
    if (user != null) {
      _userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      _notificationsRef =
          FirebaseDatabase.instance.ref('notifications/${user.uid}');
    }
  }

  void _setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _userName = _translate(context, 'student');
        _isLoading = false;
      });
      return;
    }

    _userRef.onValue.listen((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) {
        setState(() {
          _userName = _translate(context, 'student');
          _isLoading = false;
          _hasError = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      _updateUserData(data);
    }, onError: (error) {
      debugPrint('Realtime listener error: $error');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    });

    // Listen for notifications
    _notificationsRef.onValue.listen((event) {
      final snapshot = event.snapshot;
      if (snapshot.exists) {
        setState(() {
          notifications = _parseSnapshot(snapshot);
        });
      }
    });
  }

  Future<void> _loadData() async {
    try {
      //final patientsSnapshot = await _patientsRef.orderByChild('assignedStudentId').equalTo(_auth.currentUser?.uid).get();
      final notificationsSnapshot = await _notificationsRef.get();

      setState(() {
        //assignedPatients = _parseSnapshot(patientsSnapshot);
        notifications = _parseSnapshot(notificationsSnapshot);
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  List<Map<String, dynamic>> _parseSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) return [];

    final List<Map<String, dynamic>> result = [];
    final data = snapshot.value as Map<dynamic, dynamic>? ?? {};

    data.forEach((key, value) {
      if (value is Map<dynamic, dynamic>) {
        result.add(Map<String, dynamic>.from(value));
      }
    });

    return result;
  }

  void _updateUserData(Map<dynamic, dynamic> data) {
    final firstName = data['firstName']?.toString().trim() ?? '';
    final fatherName = data['fatherName']?.toString().trim() ?? '';
    final grandfatherName = data['grandfatherName']?.toString().trim() ?? '';
    final familyName = data['familyName']?.toString().trim() ?? '';

    final fullName = [
      if (firstName.isNotEmpty) firstName,
      if (fatherName.isNotEmpty) fatherName,
      if (grandfatherName.isNotEmpty) grandfatherName,
      if (familyName.isNotEmpty) familyName,
    ].join(' ');

    final imageData = data['image']?.toString() ?? '';

    setState(() {
      _userName =
          fullName.isNotEmpty ? fullName : _translate(context, 'student');
      _userImageUrl =
          imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : '';
      _isLoading = false;
      _hasError = false;
    });
  }

  String _translate(BuildContext context, String key) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return _translations[key]![languageProvider.currentLocale.languageCode] ??
        '';
  }

  bool _isArabic(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return languageProvider.currentLocale.languageCode == 'ar';
  }

  String _getErrorMessage() {
    return _translate(context, 'error_loading_data');
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 350;

    return Directionality(
      textDirection: _isArabic(context) ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          title: Text(
            _translate(context, 'app_name'),
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.language, color: Colors.white),
              onPressed: () => languageProvider.toggleLanguage(),
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.white),
            )
          ],
        ),
        body: _buildBody(context),
        bottomNavigationBar: _buildBottomNavigation(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              _getErrorMessage(),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _loadData();
                _setupRealtimeListener();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                _translate(context, 'retry'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (_retryCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '($_retryCount/$_maxRetries)',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 350;

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
        ),
        SingleChildScrollView(
          padding: EdgeInsets.only(bottom: mediaQuery.padding.bottom + 20),
          child: Column(
            children: [
              // User info section
              Container(
                margin: const EdgeInsets.all(20),
                height: isSmallScreen ? 180 : 200,
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('lib/assets/backgrownd.png'),
                    fit: BoxFit.cover,
                  ),
                  color: const Color(0x4D000000),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0x33000000),
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _userImageUrl.isNotEmpty
                              ? CircleAvatar(
                                  radius: isSmallScreen ? 30 : 40,
                                  backgroundColor: Colors.white
                                      .withAlpha((0.8 * 255).toInt()),
                                  child: ClipOval(
                                    child: Image.memory(
                                      base64Decode(_userImageUrl.replaceFirst(
                                          'data:image/jpeg;base64,', '')),
                                      width: isSmallScreen ? 60 : 80,
                                      height: isSmallScreen ? 60 : 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  radius: isSmallScreen ? 30 : 40,
                                  backgroundColor: Colors.white
                                      .withAlpha((0.8 * 255).toInt()),
                                  child: Icon(
                                    Icons.person,
                                    size: isSmallScreen ? 30 : 40,
                                    color: accentColor,
                                  ),
                                ),
                          const SizedBox(height: 15),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              _userName,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _translate(context, 'student'),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main feature boxes
              Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                  children: [
                    _buildFeatureBox(
                      context,
                      Icons.assignment,
                      _translate(context, 'view_examinations'),
                      primaryColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StudentGroupsPage(),
                          ),
                        );
                      },
                    ),
                    _buildFeatureBox(
                      context,
                      Icons.medical_services,
                      _translate(context, 'examine_patient'),
                      Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StudentGroupsPage(),
                          ),
                        );
                      },
                    ),
                    _buildFeatureBox(
                      context,
                      Icons.notifications,
                      _translate(context, 'notifications'),
                      Colors.orange,
                      badgeCount: notifications.length,
                      onTap: () {
                        _showNotificationsDialog(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_translate(context, 'notifications')),
          content: notifications.isEmpty
              ? Text(_translate(context, 'no_notifications'))
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return ListTile(
                        leading: const Icon(Icons.notifications),
                        title: Text(notification['title'] ?? ''),
                        subtitle: Text(notification['message'] ?? ''),
                        trailing: Text(notification['date'] ?? ''),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_translate(context, 'close')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeatureBox(
    BuildContext context,
    IconData icon,
    String title,
    Color color, {
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.width < 350;

    return Material(
      borderRadius: BorderRadius.circular(15),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withAlpha((0.1 * 255).toInt()),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: isSmallScreen ? 24 : 30,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 350;
    final isArabic = _isArabic(context);

    return Container(
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60 + mediaQuery.padding.bottom,
          child: Padding(
            padding: EdgeInsets.only(bottom: mediaQuery.padding.bottom),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBottomNavItem(
                    context, Icons.home, 'home', isSmallScreen, isArabic),
                _buildBottomNavItem(context, Icons.settings, 'settings',
                    isSmallScreen, isArabic),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    BuildContext context,
    IconData icon,
    String labelKey,
    bool isSmallScreen,
    bool isArabic,
  ) {
    final text = _translate(context, labelKey);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Handle navigation
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isSmallScreen ? 20 : 24,
                  color: primaryColor,
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: isArabic
                        ? (isSmallScreen ? 8 : 10)
                        : (isSmallScreen ? 9 : 11),
                    color: primaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
