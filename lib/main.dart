import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';


import 'screens/signup_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'data/notification_service.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with the generated options
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    firebaseInitialized = true;
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    // Firebase not configured yet - app will work but notifications won't
    debugPrint('Firebase initialization error: $e');
    debugPrint('App will run without push notifications. See FIREBASE_SETUP.md for setup instructions.');
  }
  
  await Supabase.initialize(
    url: 'https://mtizgqcjaxscaegizvru.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im10aXpncWNqYXhzY2FlZ2l6dnJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyOTY1NTAsImV4cCI6MjA3ODg3MjU1MH0.dv47U_i4kGEvYLV7qKVaiUQP2MuglS9AOeDifEeBsec',
  );
  
  // Initialize notification service after auth is ready (only if Firebase is configured)
  if (firebaseInitialized) {
    final notificationService = NotificationService();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Only initialize if user is logged in
      notificationService.initialize();
    }
  }
  
  runApp(const SafeZoneApp());
}

class SafeZoneApp extends StatelessWidget {
  const SafeZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeZone PH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE25749), // Red/orange primary
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9FA),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFE25749), width: 2),
          ),
        ),
      ),
      routes: {
        OnboardingScreen.routeName: (_) => const OnboardingScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
        SignUpScreen.routeName: (_) => const SignUpScreen(),
      },
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    try {
      final supa = Supabase.instance.client;
      if (supa.auth.currentUser != null) {
        return const MainShell();
      }
      return StreamBuilder<AuthState>(
        stream: supa.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final user = supa.auth.currentUser;
          if (user != null) {
            // Initialize notifications when user logs in (only if Firebase is configured)
            try {
              NotificationService().initialize();
            } catch (e) {
              // Firebase not configured - notifications won't work
              debugPrint('Notifications not available: $e');
            }
            return const MainShell();
          } else {
            // Remove token when user logs out
            try {
              NotificationService().removeToken();
            } catch (e) {
              // Ignore if Firebase not configured
            }
            return const LoginScreen();
          }
        },
      );
    } catch (_) {
      // In test environments where Supabase isn't initialized, show Login
      return const LoginScreen();
    }
  }
}
