// Suggested code may be subject to a license. Learn more: ~LicenseLog:1491448906.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_page.dart';
import '../providers/language_provider.dart';
import 'main.dart'; // Import for navigatorKey
import 'PendingPatientPage.dart';

enum UserRole { patient, dental_student, doctor, secretary, admin, security }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isPatient = true;
  bool _isLoading = false;

  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final DatabaseReference _dbRef;

  final Map<String, Map<String, String>> _translations = {
    'login': {'ar': 'دخول', 'en': 'Login'},
    'username': {'ar': 'إسم المستخدم', 'en': 'Username'},
    'password': {'ar': 'كلمة المرور', 'en': 'Password'},
    'email': {'ar': 'البريد الإلكتروني', 'en': 'Email'},
    'remember_me': {'ar': 'تذكرني', 'en': 'Remember Me'},
    'forgot_password': {'ar': 'نسيت كلمة المرور؟', 'en': 'Forgot Password?'},
    'login_button': {'ar': 'تسجيل الدخول', 'en': 'Sign In'},
    'create_account': {'ar': 'إنشاء حساب جديد', 'en': 'Create New Account'},
    'app_name': {
      'ar': 'عيادات أسنان الجامعة العربية الأمريكية',
      'en': 'Arab American University Dental Clinics'
    },
    'patient': {'ar': 'مريض', 'en': 'Patient'},
    'staff': {'ar': 'موظف/طبيب', 'en': 'Staff/Doctor'},
    'login_error': {
      'ar': 'بيانات الدخول غير صحيحة',
      'en': 'Invalid login credentials'
    },
    'reset_password_sent': {
      'ar': 'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني',
      'en': 'Password reset link sent to your email'
    },
    'username_recovery': {
      'ar': 'استعادة اسم المستخدم',
      'en': 'Username Recovery'
    },
    'ok': {'ar': 'موافق', 'en': 'OK'},
    'no_patient_account': {
      'ar': 'لا يوجد حساب مريض بهذا البريد الإلكتروني',
      'en': 'No patient account found with this email'
    },
    'no_student_account': {
      'ar': 'لا يوجد حساب طالب بهذا الاسم',
      'en': 'No student account found with this username'
    },
    'Please enter email': {
      'ar': 'الرجاء إدخال البريد الإلكتروني',
      'en': 'Please enter email'
    },
    'Please enter a valid email': {
      'ar': 'الرجاء إدخال بريد إلكتروني صحيح',
      'en': 'Please enter a valid email'
    },
    'Please enter username': {
      'ar': 'الرجاء إدخال اسم المستخدم',
      'en': 'Please enter username'
    },
    'Username cannot contain spaces': {
      'ar': 'اسم المستخدم لا يمكن أن يحتوي على مسافات',
      'en': 'Username cannot contain spaces'
    },
    'Please enter password': {
      'ar': 'الرجاء إدخال كلمة المرور',
      'en': 'Please enter password'
    },
    'Password must be at least 6 characters': {
      'ar': 'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
      'en': 'Password must be at least 6 characters'
    },
    'This account is not registered as a patient': {
      'ar': 'هذا الحساب غير مسجل كمريض',
      'en': 'This account is not registered as a patient'
    },
    'Account data inconsistency detected': {
      'ar': 'عدم تطابق في بيانات الحساب',
      'en': 'Account data inconsistency detected'
    },
    'This account has been disabled': {
      'ar': 'هذا الحساب معطل',
      'en': 'This account has been disabled'
    },
    'Too many attempts, try again later': {
      'ar': 'محاولات كثيرة جداً، يرجى المحاولة لاحقاً',
      'en': 'Too many attempts, try again later'
    },
    'Account data problem detected': {
      'ar': 'هناك مشكلة في بيانات الحساب',
      'en': 'Account data problem detected'
    },
  };

  @override
  void initState() {
    super.initState();
    _dbRef = FirebaseDatabase.instance.ref();
    _loadRememberMe();
    _checkAutoLogin();
  }

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
      if (_rememberMe) {
        if (_isPatient) {
          _emailController.text = prefs.getString('remembered_email') ?? '';
        } else {
          _usernameController.text =
              prefs.getString('remembered_username') ?? '';
        }
        // لا تغيّر _isPatient تلقائياً
      }
    });
  }

  Future<void> _saveRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', _rememberMe);
    if (_rememberMe) {
      await prefs.setString('remembered_email', _emailController.text);
      await prefs.setString('remembered_username', _usernameController.text);
      await prefs.setBool('remembered_is_patient', _isPatient);
    } else {
      await prefs.remove('remembered_email');
      await prefs.remove('remembered_username');
      await prefs.remove('remembered_is_patient');
    }
  }

  Future<void> _checkAutoLogin() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userData = await _checkUserExists(user.email!);
      if (userData != null && mounted) {
        final role = _determineUserRole(userData);
        _navigateToDashboard(role);
      }
    }
  }

  String _translate(BuildContext context, String key) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return _translations[key]![languageProvider.isEnglish ? 'en' : 'ar'] ?? '';
  }

  Future<void> _handleLogin(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    try {
      await _saveRememberMe();
      if (_isPatient) {
        await _handlePatientLogin(languageProvider);
      } else {
        await _handleStaffLogin(languageProvider);
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseError(context, e, languageProvider);
    } catch (e, stackTrace) {
      debugPrint('General Error: $e\n$stackTrace');
      _showErrorSnackbar(context, _translate(context, 'login_error'));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePatientLogin(LanguageProvider languageProvider) async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    // تحقق أولاً إذا كان المريض في pendingUsers
    final pendingSnapshot = await _dbRef
        .child('pendingUsers')
        .orderByChild('email')
        .equalTo(email)
        .once();

    if (pendingSnapshot.snapshot.value != null) {
      // إذا كان في pendingUsers، اسمح له بالدخول لكن أظهر له صفحة خاصة
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PendingPatientPage(),
          settings: RouteSettings(arguments: email),
        ),
      );
      return;
    }

    final patientData = await _checkUserExists(email);
    if (patientData == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: _translate(navigatorKey.currentContext!, 'no_patient_account'),
      );
    }

    if (patientData['role']?.toString().toLowerCase() != 'patient') {
      throw FirebaseAuthException(
        code: 'wrong-account-type',
        message: languageProvider.isEnglish
            ? 'This account is not registered as a patient'
            : 'هذا الحساب غير مسجل كمريض',
      );
    }

    await _auth.signInWithEmailAndPassword(email: email, password: password);

    final recheckPatientData = await _checkUserExists(email);
    if (recheckPatientData == null) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'inconsistent-data',
        message: languageProvider.isEnglish
            ? 'Account data inconsistency detected'
            : 'عدم تطابق في بيانات الحساب',
      );
    }

    _navigateToDashboard(UserRole.patient);
  }

  Future<void> _navigateToDashboard(UserRole role) async {
    if (!mounted) return;

    String route;
    switch (role) {
      case UserRole.patient:
        route = '/patient-dashboard';
        break;
      case UserRole.dental_student:
        route = '/student-dashboard';
        break;
      case UserRole.doctor:
        route = '/doctor-dashboard';
        break;
      case UserRole.secretary:
        route = '/secretary-dashboard';
        break;
      case UserRole.admin:
        route = '/admin-dashboard';
        break;
      case UserRole.security:
        route = '/security-dashboard';
        break;
    }

    navigatorKey.currentState?.pushReplacementNamed(route);
  }

  Future<Map<dynamic, dynamic>?> _checkUserExists(String email) async {
    try {
      final snapshot = await _dbRef
          .child('users')
          .orderByChild('email')
          .equalTo(email.toLowerCase().trim())
          .once();

      if (snapshot.snapshot.value == null) return null;

      final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
      return data.values.first;
    } catch (e) {
      debugPrint('Error checking user: $e');
      return null;
    }
  }

  UserRole _determineUserRole(Map<dynamic, dynamic> userData) {
    final role = userData['role']?.toString().toLowerCase() ?? '';

    switch (role) {
      case 'patient':
        return UserRole.patient;
      case 'dental_student':
        return UserRole.dental_student;
      case 'doctor':
        return UserRole.doctor;
      case 'secretary':
        return UserRole.secretary;
      case 'admin':
        return UserRole.admin;
      case 'security':
        return UserRole.security;
      default:
        return UserRole.patient;
    }
  }

  Future<void> _handleStaffLogin(LanguageProvider languageProvider) async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    final userRole = await _authenticateStaff(username, password);
    _navigateToDashboard(userRole);
  }

  Future<UserRole> _authenticateStaff(String username, String password) async {
    // Check in staff collection first
    final staffSnapshot = await _dbRef
        .child('staff')
        .orderByChild('username')
        .equalTo(username)
        .once();

    // If not found in staff, check in students collection
    final studentSnapshot = staffSnapshot.snapshot.value == null
        ? await _dbRef
            .child('students')
            .orderByChild('username')
            .equalTo(username)
            .once()
        : null;

    if (staffSnapshot.snapshot.value == null &&
        studentSnapshot?.snapshot.value == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: _translate(navigatorKey.currentContext!, 'no_student_account'),
      );
    }

    Map<dynamic, dynamic> userData;
    bool isStudent = false;

    if (staffSnapshot.snapshot.value != null) {
      userData =
          (staffSnapshot.snapshot.value as Map<dynamic, dynamic>).values.first;
    } else {
      userData = (studentSnapshot!.snapshot.value as Map<dynamic, dynamic>)
          .values
          .first;
      isStudent = true;
    }

    if (userData['email'] == null) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'User record is missing email',
      );
    }

    final email = userData['email'].toString();
    await _auth.signInWithEmailAndPassword(email: email, password: password);

    if (isStudent) {
      return UserRole.dental_student;
    }

    return _determineUserRole(userData);
  }

  void _handleFirebaseError(BuildContext context, FirebaseAuthException e,
      LanguageProvider languageProvider) {
    String errorMessage;
    switch (e.code) {
      case 'user-not-found':
        errorMessage = e.message ?? _translate(context, 'login_error');
        break;
      case 'wrong-password':
        errorMessage = _translate(context, 'login_error');
        break;
      case 'wrong-account-type':
      case 'missing-email':
        errorMessage = e.message ?? _translate(context, 'login_error');
        break;
      case 'user-disabled':
        errorMessage = languageProvider.isEnglish
            ? 'This account has been disabled'
            : 'هذا الحساب معطل';
        break;
      case 'too-many-requests':
        errorMessage = languageProvider.isEnglish
            ? 'Too many attempts, try again later'
            : 'محاولات كثيرة جداً، يرجى المحاولة لاحقاً';
        break;
      case 'inconsistent-data':
        errorMessage = e.message ??
            (languageProvider.isEnglish
                ? 'Account data problem detected'
                : 'هناك مشكلة في بيانات الحساب');
        break;
      default:
        errorMessage = '${_translate(context, 'login_error')} (${e.code})';
    }

    _showErrorSnackbar(context, errorMessage);
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showErrorSnackbar(navigatorKey.currentContext!,
          _translate(navigatorKey.currentContext!, 'email'));
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      _showErrorSnackbar(navigatorKey.currentContext!,
          _translate(navigatorKey.currentContext!, 'reset_password_sent'));
    } catch (e) {
      _showErrorSnackbar(navigatorKey.currentContext!,
          _translate(navigatorKey.currentContext!, 'login_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: primaryColor,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth > 700;
        return Directionality(
          textDirection: languageProvider.isEnglish
              ? TextDirection.ltr
              : TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  decoration: isWeb
                      ? BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              primaryColor,
                              accentColor.withOpacity(0.7),
                              Colors.white.withOpacity(0.7),
                            ],
                          ),
                        )
                      : null,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 8),
                        color: primaryColor,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _translate(context, 'app_name'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16, // أصغر قليلاً
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.language,
                                  color: Colors.white),
                              onPressed: () =>
                                  languageProvider.toggleLanguage(),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(isWeb ? 40.0 : 24.0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isWeb ? 420 : double.infinity,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  const SizedBox(height: 20),
                                  Image.asset(
                                    "lib/assets/aauplogo.png",
                                    width: isWeb
                                        ? 450
                                        : 200, // تكبير اللوجو للشاشات الكبيرة
                                  ),
                                  const SizedBox(height: 30),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(10),
                                      color: isWeb ? Colors.white : null,
                                      boxShadow: isWeb
                                          ? [
                                              const BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 12,
                                                offset: Offset(0, 4),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ChoiceChip(
                                                label: Text(_translate(
                                                    context, 'patient')),
                                                selected: _isPatient,
                                                selectedColor: primaryColor,
                                                labelStyle: TextStyle(
                                                  color: _isPatient
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                                onSelected: (_) => setState(() {
                                                  _isPatient = true;
                                                  _usernameController
                                                      .clear(); // مسح اسم المستخدم عند اختيار مريض
                                                }),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: ChoiceChip(
                                                label: Text(_translate(
                                                    context, 'staff')),
                                                selected: !_isPatient,
                                                selectedColor: primaryColor,
                                                labelStyle: TextStyle(
                                                  color: !_isPatient
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                                onSelected: (_) => setState(() {
                                                  _isPatient = false;
                                                  _emailController
                                                      .clear(); // مسح الإيميل عند اختيار موظف/طبيب
                                                }),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 30),
                                        Text(
                                          _translate(context, 'login'),
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 20),
                                        if (_isPatient) ...[
                                          TextFormField(
                                            controller: _emailController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            decoration: InputDecoration(
                                              labelText:
                                                  _translate(context, 'email'),
                                              prefixIcon: Icon(
                                                  Icons.email_outlined,
                                                  color: accentColor),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                    color:
                                                        Colors.grey.shade400),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                    color: primaryColor,
                                                    width: 2),
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return languageProvider
                                                        .isEnglish
                                                    ? 'Please enter email'
                                                    : 'الرجاء إدخال البريد الإلكتروني';
                                              }
                                              if (!value.contains('@')) {
                                                return languageProvider
                                                        .isEnglish
                                                    ? 'Please enter a valid email'
                                                    : 'الرجاء إدخال بريد إلكتروني صحيح';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 20),
                                        ],
                                        if (!_isPatient)
                                          Column(
                                            children: [
                                              TextFormField(
                                                controller: _usernameController,
                                                decoration: InputDecoration(
                                                  labelText: _translate(
                                                      context, 'username'),
                                                  prefixIcon: Icon(
                                                      Icons.person_outline,
                                                      color: accentColor),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    borderSide: BorderSide(
                                                        color: Colors
                                                            .grey.shade400),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    borderSide: BorderSide(
                                                        color: primaryColor,
                                                        width: 2),
                                                  ),
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return languageProvider
                                                            .isEnglish
                                                        ? 'Please enter username'
                                                        : 'الرجاء إدخال اسم المستخدم';
                                                  }
                                                  if (value.contains(' ')) {
                                                    return languageProvider
                                                            .isEnglish
                                                        ? 'Username cannot contain spaces'
                                                        : 'اسم المستخدم لا يمكن أن يحتوي على مسافات';
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 5),
                                              // Align(
                                              //   alignment: Alignment.centerLeft,
                                              //   child: TextButton(
                                              //     onPressed: _handleForgotPassword,
                                              //     child: Text(
                                              //       _translate(context, 'forgot_password'),
                                              //       style: TextStyle(color: accentColor),
                                              //     ),
                                              //   ),
                                              // ),
                                            ],
                                          ),
                                        const SizedBox(height: 20),
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          decoration: InputDecoration(
                                            labelText:
                                                _translate(context, 'password'),
                                            prefixIcon: Icon(Icons.lock_outline,
                                                color: accentColor),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                color: accentColor,
                                              ),
                                              onPressed: () => setState(() =>
                                                  _obscurePassword =
                                                      !_obscurePassword),
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade400),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: primaryColor,
                                                  width: 2),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return languageProvider.isEnglish
                                                  ? 'Please enter password'
                                                  : 'الرجاء إدخال كلمة المرور';
                                            }
                                            if (value.length < 6) {
                                              return languageProvider.isEnglish
                                                  ? 'Password must be at least 6 characters'
                                                  : 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: _rememberMe,
                                              onChanged: (value) => setState(
                                                  () => _rememberMe = value!),
                                              activeColor: primaryColor,
                                            ),
                                            Flexible(
                                              flex: 2,
                                              child: Text(
                                                _translate(
                                                    context, 'remember_me'),
                                                style: TextStyle(
                                                    color: primaryColor,
                                                    fontSize: 14),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (_isPatient) ...[
                                              const SizedBox(
                                                  width:
                                                      16), // زيادة المسافة بين تذكرني ونسيت كلمة المرور
                                              Flexible(
                                                flex: 3,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: TextButton(
                                                    onPressed:
                                                        _handleForgotPassword,
                                                    style: TextButton.styleFrom(
                                                        padding:
                                                            EdgeInsets.zero),
                                                    child: Text(
                                                      _translate(context,
                                                          'forgot_password'),
                                                      style: TextStyle(
                                                          color: accentColor,
                                                          fontSize: 14),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : () => _handleLogin(context),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: _isLoading
                                                ? const CircularProgressIndicator(
                                                    color: Colors.white)
                                                : Text(
                                                    _translate(context,
                                                        'login_button'),
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        if (_isPatient) ...[
                                          const SizedBox(height: 15),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        const SignUpPage()),
                                              );
                                            },
                                            child: Text(
                                              _translate(
                                                  context, 'create_account'),
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const FaIcon(
                                            FontAwesomeIcons.facebook),
                                        onPressed: () => launchUrl(Uri.parse(
                                            "https://www.facebook.com/aaup.edu")),
                                        color: Colors.blue[800],
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const FaIcon(
                                            FontAwesomeIcons.linkedin),
                                        onPressed: () => launchUrl(Uri.parse(
                                            "https://www.linkedin.com/school/arabamericanuniversity")),
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const FaIcon(
                                            FontAwesomeIcons.instagram),
                                        onPressed: () => launchUrl(Uri.parse(
                                            "https://www.instagram.com/Aaup_edu")),
                                        color: Colors.pinkAccent,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
