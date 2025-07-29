import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class ImageUploadWidget extends StatefulWidget {
  const ImageUploadWidget({Key? key}) : super(key: key);

  @override
  _ImageUploadWidgetState createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  File? _imageFile;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final storageRef = FirebaseStorage.instance.ref().child('uploads/$fileName');

      final uploadTask = storageRef.putFile(_imageFile!);
      final snapshot = await uploadTask;

      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save the URL to Firestore
      await FirebaseFirestore.instance.collection('images').add({
        'url': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully')),
      );

      setState(() {
        _imageFile = null; // clear image after upload
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_imageFile != null)
          Image.file(
            _imageFile!,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
          )
        else
          Container(
            width: 200,
            height: 200,
            color: Colors.grey[300],
            child: const Icon(
              Icons.image,
              size: 100,
              color: Colors.white70,
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.photo_library),
          label: const Text('Pick Image'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _uploadImage,
          icon: _isLoading
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Icon(Icons.upload),
          label: Text(_isLoading ? 'Uploading...' : 'Upload Image'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
          ),
        ),
      ],
    );
  }
}
