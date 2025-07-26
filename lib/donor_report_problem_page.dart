import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DonorReportProblemPage extends StatefulWidget {
  const DonorReportProblemPage({super.key});

  @override
  State<DonorReportProblemPage> createState() => _DonorReportProblemPageState();
}

class _DonorReportProblemPageState extends State<DonorReportProblemPage> {
  final _formKey = GlobalKey<FormState>();
  final String apiUrl = 'http://127.0.0.1:5001/donationapp-3c/us-central1/api';
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
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitProblem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
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

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$apiUrl/support/issues'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'description': _problemController.text.trim(),
          'imageUrl': imageUrl,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Problem reported successfully! Admin notified.'),
            backgroundColor: Colors.green,
          ),
        );
        _problemController.clear();
        setState(() => _imageFile = null);
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to submit problem: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
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