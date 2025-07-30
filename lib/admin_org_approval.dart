import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_notifications.dart';

class AdminOrgApprovalDashboard extends StatefulWidget {
  const AdminOrgApprovalDashboard({super.key});

  @override
  State<AdminOrgApprovalDashboard> createState() => _AdminOrgApprovalDashboardState();
}

class _AdminOrgApprovalDashboardState extends State<AdminOrgApprovalDashboard> {
  @override
  void initState() {
    super.initState();
    // Navigate to admin notifications with Organization Approvals tab selected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminNotificationsPage(initialTab: 0),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Organization Requests'),
        backgroundColor: Colors.deepPurple,
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
