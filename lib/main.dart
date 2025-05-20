import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

// Localization
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/language_provider.dart';

// Pages
import '../loginpage.dart';
import 'dashboard/patient_dashboard.dart';
import 'dashboard/doctor_dashboard.dart';
import 'dashboard/security_dashboard.dart';
import 'dashboard/secretary_dashboard.dart';
import 'dashboard/student_dashboard.dart';
import 'dashboard/admin_dashboard.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDLPuuiVMzvgNBsxDBvmM0sAslYdgZ-5v0",
          authDomain: "dcms-aaup-6e1e4.firebaseapp.com",
          projectId: "dcms-aaup-6e1e4",
          storageBucket: "dcms-aaup-6e1e4.appspot.com",
          messagingSenderId: "116279530211",
          appId: "1:116279530211:web:c5188d0bc1c6fc59e3abd6",
          measurementId: "G-XR9CCXMSWG",
          databaseURL: "https://dcms-aaup-6e1e4-default-rtdb.firebaseio.com",
        ),
      );
      print("✅ Firebase initialized for Web");
    } else {
      // On iOS and Android, use default config from GoogleService files
      await Firebase.initializeApp();
      print("✅ Firebase initialized for Mobile");
    }

    runApp(
      ChangeNotifierProvider(
        create: (context) => LanguageProvider(),
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('❌ Firebase initialization error: $e');

    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                const Text(
                  'فشل في تهيئة Firebase',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('تفاصيل الخطأ: $e', textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      routes: {
        '/patient-dashboard': (context) => const PatientDashboard(),
        '/student-dashboard': (context) => const StudentDashboard(),
        '/doctor-dashboard': (context) => const SupervisorDashboard(),
        '/secretary-dashboard': (context) => const SecretaryDashboard(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/security-dashboard': (context) => const SecurityDashboard(),
      },
      locale: languageProvider.currentLocale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LoginPage(),
    );
  }
}
