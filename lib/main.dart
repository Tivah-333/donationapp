import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'donor_home.dart';
import 'organization_home.dart';
import 'admin_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CharityBridgeApp());
}

class CharityBridgeApp extends StatelessWidget {
  const CharityBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Charity Bridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/donor': (context) => const DonorHome(),
        '/organization': (context) => const OrganizationHome(),
        '/admin': (context) => const AdminHome(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is not logged in, show login screen
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // User is logged in - fetch their role
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, roleSnapshot) {
            // Show loading indicator while fetching role
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Handle missing user document
            if (!roleSnapshot.hasData || !roleSnapshot.data!.exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FirebaseAuth.instance.signOut();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User data not found')),
                );
              });
              return const LoginScreen();
            }

            // Get user role and navigate accordingly
            final role = roleSnapshot.data!['role'] as String?;
            switch (role) {
              case 'Donor':
                return const DonorHome();
              case 'Organization':
                return const OrganizationHome();
              case 'Administrator':
                return const AdminHome();
              default:
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  FirebaseAuth.instance.signOut();
                });
                return const LoginScreen();
            }
          },
        );
      },
    );
  }
}