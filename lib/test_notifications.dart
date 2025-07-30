import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/notification_service.dart';

class TestNotificationsPage extends StatefulWidget {
  const TestNotificationsPage({super.key});

  @override
  State<TestNotificationsPage> createState() => _TestNotificationsPageState();
}

class _TestNotificationsPageState extends State<TestNotificationsPage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notifications'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Push Notifications',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Use these buttons to test different types of notifications:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            // Test Donor Notification
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _testDonorNotification(),
              icon: const Icon(Icons.notifications),
              label: const Text('Test Donor Notification'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            
            // Test Organization Notification
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _testOrganizationNotification(),
              icon: const Icon(Icons.notifications),
              label: const Text('Test Organization Notification'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            
            // Test Admin Notification
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _testAdminNotification(),
              icon: const Icon(Icons.notifications),
              label: const Text('Test Admin Notification'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 24),
            
            // Current User Info
            if (user != null) ...[
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Current User Info:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Email: ${user!.email}'),
              Text('UID: ${user!.uid}'),
              const SizedBox(height: 16),
              
              // Get FCM Token
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _getFCMToken(),
                icon: const Icon(Icons.token),
                label: const Text('Get FCM Token'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
            
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _testDonorNotification() async {
    if (user == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      await NotificationService.sendDonorNotification(
        donorId: user!.uid,
        type: 'test_notification',
        title: '🧪 Test Notification',
        message: 'This is a test push notification for donors!',
        additionalData: {
          'test': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test donor notification sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testOrganizationNotification() async {
    if (user == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      await NotificationService.sendOrganizationNotification(
        organizationId: user!.uid,
        type: 'test_notification',
        title: '🧪 Test Notification',
        message: 'This is a test push notification for organizations!',
        additionalData: {
          'test': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test organization notification sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAdminNotification() async {
    setState(() => _isLoading = true);
    
    try {
      await NotificationService.sendAdminNotification(
        type: 'test_notification',
        title: '🧪 Test Notification',
        message: 'This is a test push notification for admins!',
        additionalData: {
          'test': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test admin notification sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getFCMToken() async {
    setState(() => _isLoading = true);
    
    try {
      // Get user's FCM token from database
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      
      if (userDoc.exists) {
        final fcmToken = userDoc.data()?['fcmToken'] as String?;
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('FCM Token'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Your FCM token:'),
                  const SizedBox(height: 8),
                  SelectableText(
                    fcmToken ?? 'No token found',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting FCM token: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
} 