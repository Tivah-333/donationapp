import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DonorReportProblemPage extends StatefulWidget {
  const DonorReportProblemPage({super.key});

  @override
  State<DonorReportProblemPage> createState() => _DonorReportProblemPageState();
}

class _DonorReportProblemPageState extends State<DonorReportProblemPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _problemController = TextEditingController();
  File? _imageFile;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _problemController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitProblem() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isSubmitting = true;
        });

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        String? imageUrl;

        if (_imageFile != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('problem_images')
              .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

          await storageRef.putFile(_imageFile!);
          imageUrl = await storageRef.getDownloadURL();
        }

        // Create problem document with explicit status
        final problemDoc = await FirebaseFirestore.instance
            .collection('problems')
            .add({
          'userId': user.uid,
          'userEmail': user.email ?? 'Unknown',
          'userType': 'donor',
          'message': _problemController.text.trim(),
          'imageUrl': imageUrl,
          'response': null,
          'isResponded': false,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending', // Explicit status field
        });

        // Create admin notification with minimal initial info
        await FirebaseFirestore.instance
            .collection('admin_notifications')
            .doc(problemDoc.id)
            .set({
          'type': 'issue_report',
          'title': 'New Issue Report from Donor',
          'shortMessage': 'Problem reported by ${user.email ?? "a donor"}', // Generic initial message
          'fullMessage': _problemController.text.trim(), // Hidden until expanded
          'problemId': problemDoc.id,
          'senderId': user.uid,
          'senderEmail': user.email ?? 'Unknown',
          'senderRole': 'donor',
          'imageUrl': imageUrl,
          'read': false,
          'starred': false,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'unresolved', // Clear status for admin
          'showDetails': false, // Hide problem details initially
          'organizationEmail': '', // Will be populated if from organization
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Problem reported successfully! Admin notified.'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form and pop
        _problemController.clear();
        setState(() => _imageFile = null);
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
              const SizedBox(height: 20),
              if (_imageFile != null)
                Column(
                  children: [
                    Image.file(_imageFile!),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _imageFile = null;
                        });
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Remove Image'),
                    ),
                  ],
                ),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Attach an Optional Photo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
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