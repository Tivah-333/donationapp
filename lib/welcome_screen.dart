import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    _navigateUser();
  }

  Future<void> _navigateUser() async {
    await Future.delayed(const Duration(seconds: 2));

    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    if (user == null) {
      // Not logged in → go to Login screen
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      // User is logged in, check role
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // No data in Firestore for this user → log them out and send to Login
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final role = data['role'] as String?;
      final status = data['status'] as String? ?? 'approved';

      switch (role) {
        case 'Donor':
          Navigator.pushReplacementNamed(context, '/donor');
          break;
        case 'Organization':
          if (status == 'pending' || status == 'rejected') {
            Navigator.pushReplacementNamed(context, '/orgStatus');
          } else {
            Navigator.pushReplacementNamed(context, '/organization');
          }
          break;
        case 'Administrator':
          Navigator.pushReplacementNamed(context, '/admin');
          break;
        default:
        // Unknown role → log out and go to login
          await FirebaseAuth.instance.signOut();
          Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'app-logo',
              child: Image.asset('assets/images/logo.png', height: 120),
            ),
            const SizedBox(height: 16),
            Text(
              'Charity Bridge',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connecting donors with those in need',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.deepPurpleAccent,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
