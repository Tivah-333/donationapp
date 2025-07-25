import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image. Please try again.')),
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

        // First create the problem document
        final problemDoc = await FirebaseFirestore.instance.collection('problems').add({
          'userId': user.uid,
          'userEmail': user.email ?? 'Unknown',
          'userType': 'organization',
          'message': _problemController.text.trim(),
          'imageUrl': imageUrl,
          'response': null,
          'isResponded': false,
          'read': false,
          'timestamp': Timestamp.now(),
          'status': 'pending',  // Explicit status field
        });

        // Then create the notification with reference to the problem
        await FirebaseFirestore.instance.collection('admin_notifications').add({
          'type': 'issue_report',
          'title': 'New Issue Report',  // Added title for clarity
          'message': 'New problem reported by ${user.email ?? "Organization"}',  // Generic message
          'problemId': problemDoc.id,  // Reference to the problem document
          'senderId': user.uid,
          'senderEmail': user.email ?? 'Unknown',
          'senderRole': 'organization',
          'imageUrl': imageUrl,
          'read': false,
          'timestamp': Timestamp.now(),
          'status': 'unresolved',  // Clear status for admin
          'showDetails': false,  // Hide problem details initially
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Thank you. We received your message and will get back to you shortly!'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _problemController.clear();
          _imageFile = null;
        });

        Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to submit problem: ${e.toString()}'),  // More detailed error
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