import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/notification_service.dart';

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
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
      // TODO: Implement submission logic (e.g., save problem description and optionally the image to Firestore/storage)

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Problem reported successfully!')),
      );

        // Get user type from Firestore
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data();
        final userType = userData?['role']?.toLowerCase() ?? 'donor';
        final userTypeDisplay = userType == 'organization' ? 'Organization' : 'Donor';

        // Create the problem document
        final problemDoc = await FirebaseFirestore.instance.collection('problems').add({
          'userId': user.uid,
          'userEmail': user.email ?? 'Unknown',
          'userType': userType,
          'message': _problemController.text.trim(),
          'imageUrl': null, // No image upload
          'response': null,
          'isResponded': false,
          'read': false,
          'timestamp': Timestamp.now(),
          'status': 'pending',  // Explicit status field
        });

        // Send notification to admin based on user type
        if (userType == 'donor') {
          await NotificationService.sendDonorIssueReportNotification(
            donorId: user.uid,
            donorEmail: user.email ?? 'Unknown',
            issue: 'Problem Report',
            description: _problemController.text.trim(),
            problemId: problemDoc.id,
          );
        } else if (userType == 'organization') {
          await NotificationService.sendOrgIssueReportNotification(
            organizationId: user.uid,
            organizationEmail: user.email ?? 'Unknown',
            issue: 'Problem Report',
            description: _problemController.text.trim(),
            problemId: problemDoc.id,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Problem reported successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to report problem: $e')),
          );
        }
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
                onPressed: _submitProblem,
                child: const Text('Submit'),
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
