import 'package:flutter/material.dart';

class OrgStatusScreen extends StatelessWidget {
  final String status;

  const OrgStatusScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    String title = '';
    String message = '';
    IconData icon = Icons.info;
    Color iconColor = Colors.blue;

    if (status == 'pending') {
      title = 'Pending Approval';
      message =
      'Your organization account is under review.\nYou will be notified once approved.';
      icon = Icons.hourglass_top;
      iconColor = Colors.orange;
    } else if (status == 'rejected') {
      title = 'Application Rejected';
      message =
      'Your organization account request has been rejected.\nPlease contact support or try again.';
      icon = Icons.cancel;
      iconColor = Colors.red;
    } else {
      title = 'Unknown Status';
      message = 'Please contact support.';
      icon = Icons.error;
      iconColor = Colors.grey;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Status'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: iconColor),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
