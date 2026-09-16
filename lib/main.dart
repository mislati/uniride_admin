import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'admin_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const UnirideAdminApp());
}

class UnirideAdminApp extends StatelessWidget {
  const UnirideAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uniride Admin Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF5A5BFF),
        scaffoldBackgroundColor: const Color(0xFFF4F6FF),
        fontFamily: 'Roboto', 
      ),
      home: const AdminLoginScreen(), // Load the Login Screen
    );
  }
}