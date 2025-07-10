import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MakeDonationPage extends StatefulWidget {
  const MakeDonationPage({super.key});

  @override
  State<MakeDonationPage> createState() => _MakeDonationPageState();
}

class _MakeDonationPageState extends State<MakeDonationPage> {
  final _formKey = GlobalKey<FormState>();

  String? selectedCategory;
  String? deliveryOption;
  String? description;
  File? imageFile;
  final quantityController = TextEditingController();
  bool isLoading = false;

  String? detectedLocationName;
  Position? detectedPosition;

  final List<String> categories = [
    'Clothes',
    'Studying Materials',
    'Food Supplies',
    'Other',
  ];

  final List<String> deliveryOptions = ['Pickup', 'Drop-off'];

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          detectedLocationName = 'Location services disabled';
          detectedPosition = null;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          detectedLocationName = 'Location permission denied';
          detectedPosition = null;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = placemarks.first;

      setState(() {
        detectedPosition = position;
        detectedLocationName = '${place.locality}, ${place.country}';
      });
    } catch (e) {
      setState(() {
        detectedLocationName = 'Location error: ${e.toString()}';
        detectedPosition = null;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final ref = FirebaseStorage.instance
        .ref()
        .child('donation_images')
        .child('$userId-${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) return;

    if (detectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not detected. Cannot submit donation.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final imageUrl = imageFile != null ? await _uploadImage(imageFile!) : null;

      await FirebaseFirestore.instance.collection('donations').add({
        'userId': userId,
        'category': selectedCategory,
        'quantity': quantityController.text.trim(),
        'deliveryOption': deliveryOption,
        'description': description ?? '',
        'locationName': detectedLocationName ?? 'Unknown',
        'locationCoords': {
          'latitude': detectedPosition!.latitude,
          'longitude': detectedPosition!.longitude,
        },
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation submitted successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Make a Donation')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location displayed clearly near top
            Text(
              detectedLocationName ?? 'Detecting location...',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedCategory = value),
                    validator: (value) =>
                    value == null ? 'Please select a category' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Enter quantity' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: deliveryOption,
                    decoration: const InputDecoration(labelText: 'Delivery Option'),
                    items: deliveryOptions.map((opt) {
                      return DropdownMenuItem(
                        value: opt,
                        child: Text(opt),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => deliveryOption = value),
                    validator: (value) =>
                    value == null ? 'Please select delivery option' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      hintText: detectedLocationName ?? 'Detecting location...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    maxLines: 3,
                    decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
                    onChanged: (value) => description = value,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text('Upload Image (optional)'),
                        onPressed: _pickImage,
                      ),
                      const SizedBox(width: 10),
                      if (imageFile != null)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitDonation,
                      child: const Text('Submit Donation'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
