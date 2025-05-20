import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../providers/language_provider.dart';
import '../loginpage.dart';
import '../Shared/waiting_list_page.dart';
import '../Doctor/examined_patients_page.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _supervisorRef;

  String _supervisorName = '';
  String _supervisorImageUrl = '';
  bool _isLoading = true;
  bool _hasError = false;
  final int _retryCount = 0;
  final int _maxRetries = 3;

  final Map<String, Map<String, String>> _translations = {
    'supervisor': {'ar': 'مشرف', 'en': 'Supervisor'},
    'initial_examination': {'ar': 'الفحص الأولي', 'en': 'Initial Examination'},
    'students_evaluation': {'ar': 'تقييم الطلاب', 'en': 'Students Evaluation'},
    'waiting_list': {'ar': 'قائمة الانتظار', 'en': 'Waiting List'},
    'appointments': {'ar': 'المواعيد', 'en': 'Appointments'},
    'reports': {'ar': 'التقارير', 'en': 'Reports'},
    'profile': {'ar': 'الملف الشخصي', 'en': 'Profile'},
    'home': {'ar': 'الرئيسية', 'en': 'Home'},
    'history': {'ar': 'السجل', 'en': 'History'},
    'notifications': {'ar': 'الإشعارات', 'en': 'Notifications'},
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
    'signing_out': {'ar': 'جاري تسجيل الخروج...', 'en': 'Signing out...'},
    'sign_out_error': {'ar': 'خطأ في تسجيل الخروج', 'en': 'Sign out error'},
  };

  @override
  void initState() {
    super.initState();
    _initializeSupervisorReference();
    _setupRealtimeListener();
    final user = _auth.currentUser;
    debugPrint("Current user UID: ${user?.uid}");
  }

  void _initializeSupervisorReference() {
    final user = _auth.currentUser;
    if (user != null) {
      _supervisorRef = FirebaseDatabase.instance.ref('users/${user.uid}');
    }
  }

  void _setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _supervisorName = _translate(context, 'supervisor');
        _isLoading = false;
      });
      return;
    }

    _supervisorRef.onValue.listen((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) {
        setState(() {
          _supervisorName = _translate(context, 'supervisor');
          _isLoading = false;
          _hasError = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      _updateSupervisorData(data);
    }, onError: (error) {
      debugPrint('Realtime listener error: $error');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    });
  }

  void _updateSupervisorData(Map<dynamic, dynamic> data) {
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
      _supervisorName = fullName.isNotEmpty
          ? "د. $fullName"
          : _translate(context, 'supervisor');
      _supervisorImageUrl =
          imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : '';
      _isLoading = false;
      _hasError = false;
    });
  }

  Future<void> _loadSupervisorDataOnce() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _supervisorName = _translate(context, 'supervisor');
          _isLoading = false;
        });
        return;
      }

      final snapshot = await _supervisorRef.get();

      if (!snapshot.exists) {
        setState(() {
          _supervisorName = _translate(context, 'supervisor');
          _isLoading = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      _updateSupervisorData(data);
    } catch (e) {
      debugPrint('Error loading supervisor data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translate(context, 'error_loading_data')),
          duration: const Duration(seconds: 3),
        ),
      );
    }
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

  Future<void> _signOut() async {
    try {
      // عرض مؤشر تحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(_translate(context, 'signing_out')),
              ],
            ),
          );
        },
      );

      await _auth.signOut();

      // إغلاق مؤشر التحميل
      Navigator.of(context).pop();

      // الانتقال إلى صفحة تسجيل الدخول وإزالة جميع الصفحات السابقة
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      // إغلاق مؤشر التحميل في حالة الخطأ
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_translate(context, 'sign_out_error')}: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
              onPressed: _signOut,
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
              onPressed: _loadSupervisorDataOnce,
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
                          _supervisorImageUrl.isNotEmpty
                              ? CircleAvatar(
                                  radius: isSmallScreen ? 30 : 40,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.8),
                                  child: ClipOval(
                                    child: Image.memory(
                                      base64Decode(
                                          _supervisorImageUrl.replaceFirst(
                                              'data:image/jpeg;base64,', '')),
                                      width: isSmallScreen ? 60 : 80,
                                      height: isSmallScreen ? 60 : 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  radius: isSmallScreen ? 30 : 40,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.8),
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
                              _supervisorName,
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                      Icons.list_alt,
                      _translate(context, 'waiting_list'),
                      primaryColor,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const WaitingListPage(userRole: 'doctor'),
                          ),
                        );
                      },
                    ),
                    _buildFeatureBox(
                      context,
                      Icons.school,
                      _translate(context, 'students_evaluation'),
                      Colors.green,
                      () => _navigateTo(context, '/students_evaluation'),
                    ),
                    _buildFeatureBox(
                      context,
                      Icons.calendar_today,
                      _translate(context, 'appointments'),
                      Colors.orange,
                      () => _navigateTo(context, '/appointments'),
                    ),
                    _buildFeatureBox(
                      context,
                      Icons.assignment,
                      _translate(context, 'reports'),
                      Colors.purple,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ExaminedPatientsPage()),
                        );
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

  Widget _buildFeatureBox(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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
                _buildBottomNavItem(context, Icons.notifications,
                    'notifications', isSmallScreen, isArabic),
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

  void _navigateTo(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }
}
