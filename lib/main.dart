import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import 'home_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'donations_screen.dart';

// Firebase Options
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Determine the initial route
  final initialRoute = await _getInitialRoute();

  runApp(CharityBridgeApp(initialRoute: initialRoute));
}

/// Determine whether to go to /profile or /login
Future<String> _getInitialRoute() async {
  final prefs = await SharedPreferences.getInstance();
  final email = prefs.getString('email');
  return email != null ? '/profile' : '/login';
}

class CharityBridgeApp extends StatelessWidget {
  final String initialRoute;

  const CharityBridgeApp({Key? key, required this.initialRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Charity Bridge',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/donations': (context) => const DonationsScreen(),
      },
    );
  }
}
