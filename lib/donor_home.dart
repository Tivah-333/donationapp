import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DonorHome extends StatelessWidget {
  const DonorHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple, // Changed here to deepPurple
        iconTheme: const IconThemeData(color: Colors.black),
        actionsIconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Donor Dashboard',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.pushNamed(context, '/donor/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add_box),
              label: const Text('Make a Donation'),
              onPressed: () {
                Navigator.pushNamed(context, '/donate');
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('Donation History'),
              onPressed: () {
                Navigator.pushNamed(context, '/donor/history');
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.notifications),
              label: const Text('Notifications'),
              onPressed: () {
                Navigator.pushNamed(context, '/donor/notifications');
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.support_agent),
              label: const Text('Contact Support'),
              onPressed: () {
                Navigator.pushNamed(context, '/donor/support');
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.report_problem),
              label: const Text('Report a Problem'),
              onPressed: () {
                Navigator.pushNamed(context, '/donor/report');
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Settings'),
              onPressed: () {
                Navigator.pushNamed(context, '/donor/settings');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.authStateChanges().first;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: ${e.toString()}')),
      );
    }
  }
}
