import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DonorNotificationSetting extends StatefulWidget {
  const DonorNotificationSetting({super.key});

  @override
  State<DonorNotificationSetting> createState() => _DonorNotificationSettingState();
}

class _DonorNotificationSettingState extends State<DonorNotificationSetting> {
  bool notificationsEnabled = true; // default ON
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          notificationsEnabled = doc.data()?['notificationsEnabled'] ?? true;
          isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading preferences: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      notificationsEnabled = value;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'notificationsEnabled': value,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notificationsEnabled ? 'Notifications enabled' : 'Notifications disabled',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving preference: $e')),
      );
      setState(() {
        notificationsEnabled = !value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.deepPurple
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Enable Notifications'),
            trailing: Switch(
              value: notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
          ),
          const Divider(),
          Expanded(
            child: Center(
              child: notificationsEnabled
                  ? const Text(
                'You have no notifications yet.',
                style: TextStyle(fontSize: 16),
              )
                  : const Text(
                'Notifications are disabled.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}