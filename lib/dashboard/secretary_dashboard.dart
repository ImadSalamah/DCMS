import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/language_provider.dart';
import '../loginpage.dart';
import '../Student/patient_files.dart';
import '../Shared/waiting_list_page.dart';
import '../Shared/add_patient_page.dart';
import '../Secretry/account_approv.dart';
import 'package:flutter/foundation.dart'; // للكشف عن الويب

class SecretaryDashboard extends StatefulWidget {
  const SecretaryDashboard({super.key});

  @override
  State<SecretaryDashboard> createState() => _SecretaryDashboardState();
}

class _SecretaryDashboardState extends State<SecretaryDashboard> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _userRef;
  late DatabaseReference _patientsRef;
  late DatabaseReference _pendingAccountsRef;

  String _userName = '';
  String _userImageUrl = '';
  Uint8List? _userImageBytes;
  List<Map<String, dynamic>> waitingList = [];
  List<Map<String, dynamic>> pendingAccounts = [];
  bool _isLoading = true;
  bool _hasError = false;
  final int _retryCount = 0;
  final int _maxRetries = 3;

  final Map<String, Map<String, String>> _translations = {
    'secretary_dashboard': {
      'ar': 'لوحة السكرتارية',
      'en': 'Secretary Dashboard'
    },
    'patient_files': {'ar': 'ملفات المرضى', 'en': 'Patient Files'},
    'add_patient': {'ar': 'إضافة مريض', 'en': 'Add Patient'},
    'approve_accounts': {
      'ar': 'الموافقة على الحسابات',
      'en': 'Approve Accounts'
    },
    'waiting_list': {'ar': 'قائمة الانتظار', 'en': 'Waiting List'},
    'secretary': {'ar': 'سكرتير', 'en': 'Secretary'},
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
    }
    _patientsRef = FirebaseDatabase.instance.ref('patients');
    _pendingAccountsRef = FirebaseDatabase.instance.ref('pendingAccounts');
  }

  void _setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _userName = _translate(context, 'secretary');
        _isLoading = false;
      });
      return;
    }

    _userRef.onValue.listen((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) {
        setState(() {
          _userName = _translate(context, 'secretary');
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
  }

  Future<void> _loadData() async {
    try {
      final patientsSnapshot = await _patientsRef.get();
      final pendingSnapshot = await _pendingAccountsRef.get();

      setState(() {
        waitingList = _parseSnapshot(patientsSnapshot);
        pendingAccounts = _parseSnapshot(pendingSnapshot);
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

  void _updateUserData(Map<dynamic, dynamic> data) async {
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
    Uint8List? imageBytes;
    if (imageData.isNotEmpty) {
      try {
        imageBytes = await compute(_decodeBase64Image, imageData);
      } catch (e) {
        imageBytes = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _userName =
          fullName.isNotEmpty ? fullName : _translate(context, 'secretary');
      _userImageUrl =
          imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : '';
      _userImageBytes = imageBytes;
      _isLoading = false;
      _hasError = false;
    });
  }

  static Uint8List _decodeBase64Image(String base64Str) {
    return base64Decode(base64Str.replaceFirst('data:image/jpeg;base64,', ''));
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
    final isLargeScreen = mediaQuery.size.width >= 800 || kIsWeb;

    return Directionality(
      textDirection: _isArabic(context) ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          title: Text(
            _translate(context, 'app_name'),
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 16 : (isLargeScreen ? 24 : 18),
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: isLargeScreen
              ? null
              : Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
          actions: [
            IconButton(
              icon: const Icon(Icons.language, color: Colors.white),
              onPressed: () => languageProvider.toggleLanguage(),
            ),
            if (!kIsWeb)
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
          ],
        ),
        drawer: isLargeScreen ? null : _buildDrawer(context),
        body: isLargeScreen
            ? Row(
                children: [
                  _buildDrawer(context, permanent: true),
                  Expanded(child: _buildBody(context, isLargeScreen: true)),
                ],
              )
            : _buildBody(context),
        bottomNavigationBar:
            isLargeScreen ? null : _buildBottomNavigation(context),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, {bool permanent = false}) {
    final drawerContent = ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: primaryColor),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _userImageUrl.isNotEmpty && _userImageBytes != null
                  ? CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: ClipOval(
                        child: Image.memory(
                          _userImageBytes!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 30, color: accentColor),
                    ),
              const SizedBox(height: 10),
              Text(
                _userName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _translate(context, 'secretary'),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.home),
          title: Text(_translate(context, 'home')),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.folder),
          title: Text(_translate(context, 'patient_files')),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PatientFilesPage()));
          },
        ),
        ListTile(
          leading: const Icon(Icons.person_add),
          title: Text(_translate(context, 'add_patient')),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddPatientPage()));
          },
        ),
        ListTile(
          leading: const Icon(Icons.verified_user),
          title: Text(_translate(context, 'approve_accounts')),
          trailing: pendingAccounts.isNotEmpty
              ? CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Text(pendingAccounts.length.toString(),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)))
              : null,
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AccountApprovalPage()));
          },
        ),
        ListTile(
          leading: const Icon(Icons.list_alt),
          title: Text(_translate(context, 'waiting_list')),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const WaitingListPage(userRole: 'secretary')));
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.settings),
          title: Text(_translate(context, 'settings')),
          onTap: () {},
        ),
        if (kIsWeb)
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _logout,
          ),
      ],
    );
    if (permanent) {
      return Container(
        width: 250,
        color: Colors.white,
        child: drawerContent,
      );
    }
    return Drawer(child: drawerContent);
  }

  Widget _buildBody(BuildContext context, {bool isLargeScreen = false}) {
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
    final crossAxisCount = isLargeScreen ? 3 : 2;

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
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('lib/assets/backgrownd.png'),
                    fit: BoxFit.cover,
                  ),
                  color: Color(0x4D000000),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                  boxShadow: [
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
                          _userImageUrl.isNotEmpty && _userImageBytes != null
                              ? CircleAvatar(
                                  radius: isSmallScreen ? 30 : 40,
                                  backgroundColor: Color.fromARGB(
                                    (Colors.white.a * 255.0 * 0.8).round() &
                                        0xff,
                                    (Colors.white.r * 255.0).round() & 0xff,
                                    (Colors.white.g * 255.0).round() & 0xff,
                                    (Colors.white.b * 255.0).round() & 0xff,
                                  ),
                                  child: ClipOval(
                                    child: Image.memory(
                                      _userImageBytes!,
                                      width: isSmallScreen ? 60 : 80,
                                      height: isSmallScreen ? 60 : 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  radius: isSmallScreen ? 30 : 40,
                                  backgroundColor: Color.fromARGB(
                                    (Colors.white.a * 255.0 * 0.8).round() &
                                        0xff,
                                    (Colors.white.r * 255.0).round() & 0xff,
                                    (Colors.white.g * 255.0).round() & 0xff,
                                    (Colors.white.b * 255.0).round() & 0xff,
                                  ),
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
                            _translate(context, 'secretary'),
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
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                  children: [
                    _buildFeatureBox(
                      context,
                      Icons.folder,
                      _translate(context, 'patient_files'),
                      primaryColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const PatientFilesPage()),
                        );
                      },
                    ),
                    _buildFeatureBox(
                      context,
                      Icons.person_add,
                      _translate(context, 'add_patient'),
                      Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AddPatientPage()),
                        );
                      },
                    ),
                    _buildFeatureBox(
                      context,
                      Icons.verified_user,
                      _translate(context, 'approve_accounts'),
                      Colors.orange,
                      badgeCount: pendingAccounts.length,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const AccountApprovalPage()),
                        );
                      },
                    ),
                    _buildFeatureBox(
                      context,
                      Icons.list_alt, // أيقونة القائمة بدلاً من أيقونة الملف
                      _translate(context,
                          'waiting_list'), // استخدام ترجمة "قائمة الانتظار" بدلاً من "ملفات المرضى"
                      primaryColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const WaitingListPage(userRole: 'secretary'),
                          ),
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
                      color: Color.fromARGB(
                        (color.a * 255.0 * 0.1).round() & 0xff,
                        (color.r * 255.0).round() & 0xff,
                        (color.g * 255.0).round() & 0xff,
                        (color.b * 255.0).round() & 0xff,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: isSmallScreen ? 24 : 30,
                      color: Color.fromARGB(
                        (primaryColor.a * 255.0 * 1.0).round() & 0xff,
                        (primaryColor.r * 255.0).round() & 0xff,
                        (primaryColor.g * 255.0).round() & 0xff,
                        (primaryColor.b * 255.0).round() & 0xff,
                      ),
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
