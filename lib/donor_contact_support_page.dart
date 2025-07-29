import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/notification_service.dart';

class DonorContactSupportPage extends StatefulWidget {
  const DonorContactSupportPage({super.key});

  @override
  State<DonorContactSupportPage> createState() => _DonorContactSupportPageState();
}

class _DonorContactSupportPageState extends State<DonorContactSupportPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _submitSupportRequest() {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() => _isSubmitting = true);

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        // Send notification to admin
        await NotificationService.sendDonorSupportNotification(
          donorId: user.uid,
          donorEmail: user.email ?? 'Unknown',
          message: _messageController.text.trim(),
        );

        // Create support request in Firestore
        await FirebaseFirestore.instance.collection('support_requests').add({
          'userId': user.uid,
          'userEmail': user.email ?? 'Unknown',
          'userType': 'donor',
          'message': _messageController.text.trim(),
          'status': 'pending',
          'response': null,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Support request sent successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send support request: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Support'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Need help? Send us a message and we\'ll get back to you as soon as possible.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _messageController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Your Message',
                  border: OutlineInputBorder(),
                  hintText: 'Describe your issue or question here...',
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Please enter a message' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitSupportRequest,
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Sending...'),
                          ],
                        )
                      : const Text('Send Message'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
