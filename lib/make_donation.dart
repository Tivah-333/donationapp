// Keep your existing imports
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart' as loc;
import 'package:http/http.dart' as http; // For HTTP requests
import 'dart:convert'; // For jsonDecode

class MakeDonationPage extends StatefulWidget {
  const MakeDonationPage({super.key});

  @override
  State<MakeDonationPage> createState() => _MakeDonationPageState();
}

class _MakeDonationPageState extends State<MakeDonationPage> {
  final _formKey = GlobalKey<FormState>();

  List<Map<String, TextEditingController>> _items = [];
  String? _selectedDeliveryOption;
  String? _detectedDistrict;  // <-- only district saved here
  bool _isSubmitting = false;
  loc.LocationData? _currentLocation;

  final TextEditingController _pickupStationController = TextEditingController();

  final List<String> _categories = [
    'Clothes',
    'Food Supplies',
    'Medical Supplies',
    'School Supplies',
    'Hygiene Products',
    'Electronics',
    'Furniture',
    'Others',
  ];

  final List<String> _deliveryOptions = ['Pickup', 'Drop-off'];

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

  @override
  void initState() {
    super.initState();
    _addNewItem();
    _detectLocation();
  }

  void _addNewItem() {
    _items.add({
      'title': TextEditingController(),
      'description': TextEditingController(),
      'quantity': TextEditingController(),
      'category': TextEditingController(text: 'Clothes'),
    });
    setState(() {});
  }

  Future<void> _detectLocation() async {
    try {
      final loc.Location location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          setState(() => _detectedDistrict = 'Location services disabled');
          return;
        }
      }

      loc.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          setState(() => _detectedDistrict = 'Location permission denied');
          return;
        }
      }

      final locationData = await location.getLocation();
      _currentLocation = locationData;
      await _reverseGeocodeDistrict(locationData.latitude, locationData.longitude);
    } catch (_) {
      setState(() => _detectedDistrict = 'Unable to detect location');
    }
  }

  // Reverse geocode to get mostly the district (administrative area) using OpenStreetMap Nominatim API
  Future<void> _reverseGeocodeDistrict(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    try {
      final url =
      Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng');

      final response = await http.get(url, headers: {
        'User-Agent': 'CharityBridge/1.0 (ainebyoonadativah@gmail.com)',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final address = data['address'] ?? {};
        String district = address['county'] ?? address['state_district'] ?? address['state'] ?? '';

        if (district.isEmpty) {
          district = 'Unknown district';
        }

        setState(() {
          _detectedDistrict = district;
        });

        // Debug print
        print('Detected district: $_detectedDistrict');
      } else {
        setState(() => _detectedDistrict = 'Unknown district');
      }
    } catch (e) {
      print('Reverse geocode error: $e');
      setState(() => _detectedDistrict = 'Unknown district');
    }
  }

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDeliveryOption == null || _selectedDeliveryOption!.isEmpty) {
      _showError('Please select a delivery option.');
      return;
    }

    // pickup station must be typed manually (required)
    if (_selectedDeliveryOption == 'Pickup' && _pickupStationController.text.trim().isEmpty) {
      _showError('Please enter the pickup station.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final donationRef = FirebaseFirestore.instance.collection('donations').doc();

      await donationRef.set({
        'deliveryOption': _selectedDeliveryOption,
        'pickupStation': _selectedDeliveryOption == 'Pickup' ? _pickupStationController.text.trim() : null,
        'location': _detectedDistrict,  // <-- save district here
        'donorId': user.uid,
        'donorEmail': user.email,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      for (var item in _items) {
        await donationRef.collection('items').add({
          'title': item['title']!.text.trim(),
          'description': item['description']!.text.trim(),
          'quantity': int.parse(item['quantity']!.text),
          'category': item['category']!.text,
        });
      }

      await FirebaseFirestore.instance.collection('admin_notifications').add({
        'type': 'donation',
        'category': 'donations',
        'title': 'New Donation from ${user.email}',
        'message': '${user.email} donated ${_items.length} item(s) - ${DateTime.now().toLocal()}',
        'donorEmail': user.email,
        'donationId': donationRef.id,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'starred': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donation submitted successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError(_getFriendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _getFriendlyErrorMessage(Object e) {
    final errorStr = e.toString().toLowerCase();
    if (errorStr.contains('network')) return 'No internet connection.';
    if (errorStr.contains('timeout')) return 'The request timed out.';
    return 'An error occurred. Please try again.';
  }

  @override
  void dispose() {
    for (var item in _items) {
      item.values.forEach((c) => c.dispose());
    }
    _pickupStationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Make a Donation'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_detectedDistrict != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Detected District: $_detectedDistrict',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              for (int i = 0; i < _items.length; i++) ...[
                const Divider(thickness: 1),
                DropdownButtonFormField<String>(
                  value: _items[i]['category']!.text,
                  items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (val) => setState(() => _items[i]['category']!.text = val ?? 'Clothes'),
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _items[i]['title'],
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: _categoryHints[_items[i]['category']!.text]?['title'] ?? '',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Enter title' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _items[i]['description'],
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: _categoryHints[_items[i]['category']!.text]?['description'] ?? '',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Enter description' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _items[i]['quantity'],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    hintText: _categoryHints[_items[i]['category']!.text]?['quantity'] ?? '',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter quantity';
                    final num = int.tryParse(val);
                    if (num == null || num <= 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addNewItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Item'),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedDeliveryOption,
                items: _deliveryOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDeliveryOption = value;
                    if (value != 'Pickup') _pickupStationController.clear();
                  });
                },
                decoration: const InputDecoration(labelText: 'Delivery Option', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Please select a delivery option.' : null,
              ),
              const SizedBox(height: 16),
              if (_selectedDeliveryOption == 'Pickup') ...[
                TextFormField(
                  controller: _pickupStationController,
                  decoration: const InputDecoration(
                    labelText: 'Pickup Station',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the pickup station';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitDonation,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Donation', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
