import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class OrganizationHome extends StatefulWidget {
  const OrganizationHome({super.key});

  @override
  State<OrganizationHome> createState() => _OrganizationHomeState();
}

class _OrganizationHomeState extends State<OrganizationHome> {
  String? location;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          location = 'Location permission denied';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        location = '📍 ${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';
      });
    } catch (e) {
      setState(() {
        location = 'Could not get location';
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.authStateChanges().first;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: ${e.toString()}')),
      );
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
            // Welcome and location
            Text('👋 Welcome, Organization!', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              location ?? 'Detecting location...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),

            const SizedBox(height: 24),

            // Donation Statistics Button
            _buildActionButton(context, Icons.bar_chart, 'View Donation Statistics', '/organization/statistics'),

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
