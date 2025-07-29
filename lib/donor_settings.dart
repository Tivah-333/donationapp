import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'donor_profile.dart';  // Import ProfilePage (adjust path if needed)
import 'help_faq_page.dart'; // Import HelpFAQPage (adjust path if needed)
import 'widgets/password_change_dialog.dart';

class DonorSettingsPage extends StatefulWidget {
  const DonorSettingsPage({super.key});

  @override
  State<DonorSettingsPage> createState() => _DonorSettingsPageState();
}

class _DonorSettingsPageState extends State<DonorSettingsPage> {
  final user = FirebaseAuth.instance.currentUser;
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          isDarkMode = data['darkMode'] ?? false;
        });
      }
    }
  }

  Future<void> _updateDarkMode(bool value) async {
    setState(() => isDarkMode = value);
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'darkMode': value,
    });
  }

  Future<void> _changePassword() async {
    await showDialog(
      context: context,
      builder: (context) => const PasswordChangeDialog(),
    );
  }



  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to permanently delete your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true && user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).delete();
        await user!.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('Enable Dark Theme'),
            value: isDarkMode,
            onChanged: _updateDarkMode,
          ),

          const Divider(height: 32),

          const Text('Security', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock),
            label: const Text('Change Password'),
            onPressed: _changePassword,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & FAQ'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpFAQPage()),
              );
            },
          ),

          const Divider(height: 32),

          const Text('Location Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(location ?? 'Getting location...')),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _getLocation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
