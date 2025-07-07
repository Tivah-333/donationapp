import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static Future<void> logout(BuildContext context) async {
    try {
      // Clear authentication state
      await FirebaseAuth.instance.signOut();

      // Clear Firestore cache
      await FirebaseFirestore.instance.clearPersistence();

      // Reset navigation stack completely
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          '/welcome',
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    }
  }
}