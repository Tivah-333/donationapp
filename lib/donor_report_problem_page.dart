import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/notification_service.dart';

class DonorReportProblemPage extends StatefulWidget {
  const DonorReportProblemPage({super.key});

  @override
  State<DonorReportProblemPage> createState() => _DonorReportProblemPageState();
}

class _DonorReportProblemPageState extends State<DonorReportProblemPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _problemController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _problemController.dispose();
    super.dispose();
  }

  Future<void> _submitProblem() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isSubmitting = true;
        });

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        // Create the problem document
        final problemDoc = await FirebaseFirestore.instance.collection('problems').add({
          'userId': user.uid,
          'userEmail': user.email ?? 'Unknown',
          'userType': 'donor',
          'message': _problemController.text.trim(),
          'imageUrl': null, // No image upload
          'response': null,
          'isResponded': false,
          'read': false,
          'timestamp': Timestamp.now(),
          'status': 'pending',
        });

        // Send notification to admin using NotificationService
        await NotificationService.sendDonorIssueReportNotification(
          donorId: user.uid,
          donorEmail: user.email ?? 'Unknown',
          issue: 'Problem Report',
          description: _problemController.text.trim(),
          problemId: problemDoc.id,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Problem reported successfully! Admin notified.'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form and pop
        _problemController.clear();
        Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Problem'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Describe the problem you are facing:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _problemController,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter problem details here...',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe your problem';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitProblem,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}