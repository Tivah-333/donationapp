import 'dart:convert'; // Added for JSON decoding and HTTP
import 'package:http/http.dart' as http; // Added for HTTP requests
import 'package:flutter/foundation.dart' show kIsWeb; // Added for platform check

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateDonationRequestPage extends StatefulWidget {
  const CreateDonationRequestPage({super.key});

  @override
  State<CreateDonationRequestPage> createState() => _CreateDonationRequestPageState();
}

class _CreateDonationRequestPageState extends State<CreateDonationRequestPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  String _selectedCategory = 'Clothes';
  bool _isSubmitting = false;
  bool _isDetectingLocation = true;

  final List<String> _categories = [
    'Clothes',
    'Food',
    'Medical Supplies',
    'School Supplies',
    'Hygiene Products',
    'Other'
  ];

  final Map<String, Map<String, String>> _categoryHints = {
    'Clothes': {
      'title': 'E.g., Jacket, Shirt, Trousers',
      'quantity': 'E.g., Number of items (e.g., 3)',
    },
    'Food Supplies': {
      'title': 'E.g., Rice, Maize Flour, Beans',
      'quantity': 'E.g., Weight in kilograms (e.g., 5)',
    },
    'Medical Supplies': {
      'title': 'E.g., First Aid Kit, Bandages',
      'quantity': 'E.g., Number of items',
    },
    'School Supplies': {
      'title': 'E.g., Notebooks, Pens',
      'quantity': 'E.g., Number of items',
    },
    'Hygiene Products': {
      'title': 'E.g., Soap, Sanitary Pads',
      'quantity': 'E.g., Number of items or packs',
    },
    'Electronics': {
      'title': 'E.g., Laptop, Charger',
      'quantity': 'E.g., Number of items',
    },
    'Furniture': {
      'title': 'E.g., Chair, Table',
      'quantity': 'E.g., Number of items',
    },
    'Others': {
      'title': 'E.g., Specify item',
      'quantity': 'E.g., Number or weight',
    },
  };

  String get _titleHint => _categoryHints[_selectedCategory]?['title'] ?? 'Enter title';
  String get _quantityHint => _categoryHints[_selectedCategory]?['quantity'] ?? 'Enter quantity';

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    print('Starting location detection...');
    setState(() => _isDetectingLocation = true);
    try {
      final loc.Location location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      print('Service enabled: $serviceEnabled');
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        print('Service requested: $serviceEnabled');
        if (!serviceEnabled) {
          setState(() => _detectedLocation = 'Location services disabled');
          return;
        }
      }

      loc.PermissionStatus permissionGranted = await location.hasPermission();
      print('Permission status: $permissionGranted');
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        print('Permission requested: $permissionGranted');
        if (permissionGranted != loc.PermissionStatus.granted) {
          setState(() => _detectedLocation = 'Location permission denied');
          return;
        }
      }

      final locationData = await location.getLocation();
      print('Location data: ${locationData.latitude}, ${locationData.longitude}');
      await _reverseGeocode(locationData.latitude, locationData.longitude);
    } catch (e) {
      print('Error detecting location: $e');
      setState(() => _detectedLocation = 'Unable to detect location');
    } finally {
      setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _reverseGeocode(double? lat, double? lng) async {
    print('Starting reverse geocode...');
    if (lat == null || lng == null) {
      print('Latitude or longitude is null');
      return;
    }

    if (kIsWeb) {
      await _reverseGeocodeWeb(lat, lng);
    } else {
      await _reverseGeocodeMobile(lat, lng);
    }
  }

  Future<void> _reverseGeocodeWeb(double lat, double lng) async {
    final apiKey = 'AIzaSyA48TwKXXwt0-SfH9UQoMtMwRxsPggSUbs';
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey');

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      print('Google Geocode API response: $data');

      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final formattedAddress = data['results'][0]['formatted_address'];
        
        // Check if the address contains Plus Code (starts with a pattern like 7H73+2VW)
        if (formattedAddress.contains(RegExp(r'[A-Z0-9]{4}\+[A-Z0-9]{3,4}')) || 
            formattedAddress.contains(RegExp(r'[A-Z0-9]{5}\+[A-Z0-9]{3,4}'))) {
          // Try to get a more readable address from other results
          for (final result in data['results']) {
            final address = result['formatted_address'];
            if (!address.contains(RegExp(r'[A-Z0-9]{4}\+[A-Z0-9]{3,4}')) && 
                !address.contains(RegExp(r'[A-Z0-9]{5}\+[A-Z0-9]{3,4}'))) {
              setState(() {
                _detectedLocation = address;
              });
              return;
            }
          }
          // If all results contain Plus Codes, use a simplified version
          setState(() {
            _detectedLocation = 'Kampala, Uganda'; // Default to Kampala
          });
        } else {
          setState(() {
            _detectedLocation = formattedAddress;
          });
        }
      } else {
        setState(() {
          _detectedLocation = 'Kampala, Uganda'; // Default location
        });
      }
    } catch (e) {
      print('Reverse geocode failed on web: $e');
      setState(() {
        _detectedLocation = 'Kampala, Uganda'; // Default location
      });
    }
  }

  Future<void> _reverseGeocodeMobile(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      print('Placemarks: $placemarks');

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final List<String> parts = [
          place.name ?? '',
          place.street ?? '',
          place.subLocality ?? '',
          place.locality ?? '',
          place.administrativeArea ?? '',
          place.country ?? ''
        ].where((e) => e.trim().isNotEmpty).toList();

        // If we have meaningful location data, use it
        if (parts.isNotEmpty) {
          setState(() {
            _detectedLocation = parts.join(', ');
          });
        } else {
          // Fallback to a readable location
          setState(() {
            _detectedLocation = 'Kampala, Uganda';
          });
        }
      } else {
        setState(() => _detectedLocation = 'Kampala, Uganda');
      }
    } catch (e) {
      print('Reverse geocode failed on mobile: $e');
      setState(() => _detectedLocation = 'Kampala, Uganda');
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    
    try {
      // Create the donation request
      final requestDoc = await FirebaseFirestore.instance.collection('donation_requests').add({
        'title': _titleController.text.trim(),
        'quantity': int.parse(_quantityController.text),
        'category': _selectedCategory,
        'location': _detectedLocation,
        'organizationId': user?.uid,
        'organizationEmail': user?.email,
        'status': 'pending',
        'timestamp': Timestamp.now(),
      });

      // Update organization's location in their profile if they don't have one
      if (user?.uid != null && _detectedLocation != null && _detectedLocation != 'Unable to detect location') {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
        final userData = userDoc.data();
        final currentLocation = userData?['location'];
        
        // Only update if organization doesn't have a location or has placeholder
        if (currentLocation == null || 
            currentLocation.toString().contains('Location to be detected') ||
            currentLocation.toString().contains('GeoPoint')) {
          await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
            'location': _detectedLocation,
          });
          print('✅ Updated organization location to: $_detectedLocation');
        }
      }

      // Create admin notification
      await FirebaseFirestore.instance.collection('admin_notifications').add({
        'userId': 'admin',
        'type': 'approval',
        'title': 'New Donation Request',
        'message': 'Organization ${user?.email ?? 'Unknown'} has submitted a donation request: ${_titleController.text.trim()}',
        'organizationEmail': user?.email ?? 'Unknown',
        'requestId': requestDoc.id,
        'timestamp': Timestamp.now(),
        'read': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donation request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear form
        _titleController.clear();
        _quantityController.clear();
        _selectedCategory = 'Clothes';
        
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to submit request. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('donation_requests').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'quantity': int.parse(_quantityController.text),
        'category': _selectedCategory,
        'organizationId': user?.uid,
        'status': 'pending',
        'timestamp': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donation request submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Donation Request'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Improved Detected Location UI
            Card(
              color: Colors.deepPurple.shade50,
              margin: const EdgeInsets.only(bottom: 16.0),
              child: ListTile(
                leading: _isDetectingLocation
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on, color: Colors.deepPurple),
                title: Text(
                  _detectedLocation == null
                      ? 'Detecting location...'
                      : _detectedLocation!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _detectedLocation == null || _detectedLocation == 'Unable to detect location'
                        ? Colors.red
                        : Colors.black,
                  ),
                ),
                subtitle: _detectedLocation == 'Unable to detect location'
                    ? const Text('Could not detect your location.', style: TextStyle(color: Colors.red))
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isDetectingLocation ? null : _detectLocation,
                  tooltip: 'Refresh location',
                ),
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
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
                      onPressed: _isSubmitting ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit Request', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
