import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'donor_profile.dart';  // Import ProfilePage (adjust path if needed)
import 'help_faq_page.dart'; // Import HelpFAQPage (adjust path if needed)
import 'widgets/password_change_dialog.dart';

class DonorSettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;

  const DonorSettingsPage({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  @override
  State<DonorSettingsPage> createState() => _DonorSettingsPageState();
}

class _DonorSettingsPageState extends State<DonorSettingsPage> {
  final user = FirebaseAuth.instance.currentUser;
  late bool isDarkMode;

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.isDarkMode;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load dark mode or other settings if saved in Firestore or locally
    // For now, default false (already set)
  }

  Future<void> _updateDarkMode(bool value) async {
    setState(() {
      isDarkMode = value;
    });
    widget.onDarkModeChanged(value);
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
        content: const Text('Are you sure you want to permanently delete your account? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && user != null) {
      try {
        await FirebaseAuth.instance.signOut(); // Sign out first

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

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.deepPurple, // Changed here to deep purple
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DonorProfilePage()),
              );
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Enable Dark Theme'),
            value: isDarkMode,
            onChanged: _updateDarkMode,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            onTap: _changePassword,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & FAQ'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpFAQPage(userType: 'donor')),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Logout'),
            onTap: _logout,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}

