import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/profile_picture_widget.dart';

class OrganizationHome extends StatefulWidget {
  const OrganizationHome({super.key});

  @override
  State<OrganizationHome> createState() => _OrganizationHomeState();
}

class _OrganizationHomeState extends State<OrganizationHome> {
  @override
  void initState() {
    super.initState();
    _checkOrganizationStatus();
  }

  Future<void> _checkOrganizationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final data = userDoc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'approved';

      if (status == 'rejected') {
        // Force logout and redirect to login
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your organization has been rejected. You cannot access the app.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      } else if (status == 'pending') {
        // Redirect to status screen
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/orgStatus');
        }
      }
    } catch (e) {
      print('Error checking organization status: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Dashboard'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Notifications',
            onPressed: () => Navigator.pushNamed(context, '/organization/notifications'),
          ),
          const SizedBox(width: 8),
          ProfilePictureWidget(
            size: 32,
            onTap: () {
              Navigator.pushNamed(context, '/organization/settings');
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Welcome message
            Text('👋 Welcome, Organization!', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),

            // Donation Statistics Button
            _buildActionButton(context, Icons.bar_chart, 'View Donation Statistics', '/organization/statistics'),

            const SizedBox(height: 16),

            // My Donation Requests Button
            _buildActionButton(context, Icons.list_alt, 'My Donation Requests', '/organization/donation-requests'),

            const SizedBox(height: 16),

            // Quick Actions
            _buildActionButton(context, Icons.add_circle, 'Create New Donation Request', '/createRequest'),

            _buildActionButton(context, Icons.settings, 'Settings', '/organization/settings'),

            const SizedBox(height: 24),
            const Divider(),

            // Support Options
            _buildTextAction(Icons.report_problem, 'Report a Problem', () {
              Navigator.pushNamed(context, '/reportProblem');
            }),

            _buildTextAction(Icons.support_agent, 'Contact Us for Support', () {
              Navigator.pushNamed(context, '/contactSupport');
            }),


          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, String route) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () {
          Navigator.pushNamed(context, route);
        },
      ),
    );
  }

  Widget _buildTextAction(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(label),
      onTap: onTap,
    );
  }
}
