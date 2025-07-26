import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateDonationRequestPage extends StatefulWidget {
  const CreateDonationRequestPage({super.key});

  @override
  State<CreateDonationRequestPage> createState() => _CreateDonationRequestPageState();
}

class _CreateDonationRequestPageState extends State<CreateDonationRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final String apiUrl = 'http://127.0.0.1:5001/donationapp-3c/us-central1/api';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String? _selectedCategory = 'Clothes';
  String? _detectedLocation;
  bool _isSubmitting = false;
  final List<String> _categories = [
    'Clothes',
    'Food Supplies',
    'Medical Supplies',
    'School Supplies',
    'Hygiene Products',
    'Electronics',
    'Furniture',
    'Others'
  ];

  final Map<String, Map<String, String>> _categoryHints = {
    'Clothes': {
      'title': 'E.g., Jacket, Shirt, Trousers',
      'description': 'E.g., Size L, Color blue, Condition good',
      'quantity': 'E.g., Number of items (e.g., 3)',
    },
    'Food Supplies': {
      'title': 'E.g., Rice, Maize Flour, Beans',
      'description': 'E.g., Weight in kg, Expiry date',
      'quantity': 'E.g., Weight in kilograms (e.g., 5)',
    },
    'Medical Supplies': {
      'title': 'E.g., First Aid Kit, Bandages',
      'description': 'E.g., Quantity, Expiry date, Condition',
      'quantity': 'E.g., Number of items',
    },
    'School Supplies': {
      'title': 'E.g., Notebooks, Pens',
      'description': 'E.g., Quantity, Condition',
      'quantity': 'E.g., Number of items',
    },
    'Hygiene Products': {
      'title': 'E.g., Soap, Sanitary Pads',
      'description': 'E.g., Quantity, Expiry date',
      'quantity': 'E.g., Number of items or packs',
    },
    'Electronics': {
      'title': 'E.g., Laptop, Charger',
      'description': 'E.g., Brand, Condition, Model',
      'quantity': 'E.g., Number of items',
    },
    'Furniture': {
      'title': 'E.g., Chair, Table',
      'description': 'E.g., Condition, Material',
      'quantity': 'E.g., Number of items',
    },
    'Others': {
      'title': 'E.g., Specify item',
      'description': 'E.g., Details about the item',
      'quantity': 'E.g., Number or weight',
    },
  };

  String get _titleHint => _categoryHints[_selectedCategory]?['title'] ?? 'Enter title';
  String get _descriptionHint => _categoryHints[_selectedCategory]?['description'] ?? 'Enter description';
  String get _quantityHint => _categoryHints[_selectedCategory]?['quantity'] ?? 'Enter quantity';

  // List to hold multiple requests before submission
  List<Map<String, dynamic>> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    try {
      final loc.Location location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          setState(() => _detectedLocation = 'Location services disabled');
          return;
        }
      }

      loc.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          setState(() => _detectedLocation = 'Location permission denied');
          return;
        }
      }

      final locationData = await location.getLocation();
      await _reverseGeocode(locationData.latitude, locationData.longitude);
    } catch (e) {
      setState(() {
        _detectedLocation = 'Unable to detect location';
      });
    }
  }

  Future<void> _reverseGeocode(double? lat, double? lng) async {
    if (lat == null || lng == null) return;

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _detectedLocation =
          '${place.name}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
        });
      }
    } catch (e) {
      setState(() {
        _detectedLocation = 'Unknown location';
      });
    }
  }

  void _addRequestToList() {
    if (!_formKey.currentState!.validate()) return;

    final newRequest = {
      'item': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'quantity': int.parse(_quantityController.text),
      'category': _selectedCategory,
      'locationName': _detectedLocation,
    };

    setState(() {
      _pendingRequests.add(newRequest);
      // Clear the form for next request
      _titleController.clear();
      _descriptionController.clear();
      _quantityController.clear();
      _selectedCategory = 'Clothes';
    });
  }

  Future<void> _submitAllRequests() async {
    if (_pendingRequests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No requests to submit.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    try {
      final idToken = await user?.getIdToken();
      for (var req in _pendingRequests) {
        final response = await http.post(
          Uri.parse('$apiUrl/donations'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            ...req,
            'orgId': user?.uid,
            'status': 'pending',
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to submit request: ${response.body}');
        }
      }

      setState(() {
        _pendingRequests.clear();
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All donation requests submitted successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _removeRequestAt(int index) {
    setState(() {
      _pendingRequests.removeAt(index);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Donation Request'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    if (_detectedLocation != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Detected Location: $_detectedLocation',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      items: _categories
                          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedCategory = value),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      value == null || value.isEmpty ? 'Please select a category.' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: _titleHint,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      value == null || value.isEmpty ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: _descriptionHint,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      value == null || value.isEmpty ? 'Please enter a description' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        hintText: _quantityHint,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter a quantity';
                        final number = int.tryParse(value);
                        if (number == null || number <= 0) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _addRequestToList,
                      child: const Text('Add Request', style: TextStyle(fontSize: 16)),
                    ),

                    const SizedBox(height: 24),

                    if (_pendingRequests.isNotEmpty)
                      const Text(
                        'Requests to Submit:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),

                    if (_pendingRequests.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _pendingRequests.length,
                        itemBuilder: (context, index) {
                          final req = _pendingRequests[index];
                          return ListTile(
                            title: Text(req['item'] ?? ''),
                            subtitle:
                            Text('Quantity: ${req['quantity']} | Category: ${req['category']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeRequestAt(index),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitAllRequests,
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit All Requests', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}