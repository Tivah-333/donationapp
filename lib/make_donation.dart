import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pickup_location_screen.dart';

class MakeDonationPage extends StatefulWidget {
  const MakeDonationPage({super.key});

  @override
  State<MakeDonationPage> createState() => _MakeDonationPageState();
}

class _MakeDonationPageState extends State<MakeDonationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String _selectedCategory = 'Clothes';
  String? _selectedDeliveryOption;
  String? _detectedLocation;
  bool _isSubmitting = false;
  bool _isDetectingLocation = true;

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

  Future<void> _handlePickupStationSelection() async {
    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => PickupLocationScreen()),
      );

      if (result != null && mounted) {
        print('Pickup result: $result');
        setState(() {
          _pickupStationController.text = result['address'] ?? '';
        });
      }
    } catch (e) {
      print('Pickup selection error: $e');
      _showError('Failed to select pickup station');
    }
  }

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDeliveryOption == null || _selectedDeliveryOption!.isEmpty) {
      _showError('Please select a delivery option.');
      return;
    }

    if (_selectedDeliveryOption == 'Pickup' && _pickupStationController.text.trim().isEmpty) {
      _showError('Please select a pickup station.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final donationRef = FirebaseFirestore.instance.collection('donations').doc();

      await donationRef.set({
        'deliveryOption': _selectedDeliveryOption,
        'pickupStation': _selectedDeliveryOption == 'Pickup' ? _pickupStationController.text.trim() : null,
        'location': _detectedLocation ?? 'Unknown location',
        'donorId': user.uid,
        'donorEmail': user.email,
        'status': 'approved',
        'timestamp': FieldValue.serverTimestamp(),
        'categories': [_selectedCategory],
        'totalItems': 1,
        'deliveryType': _selectedDeliveryOption == 'Pickup' ? 'pickup_station' : 'drop_off',
        'title': _titleController.text.trim(),
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 1,
        'categorySummary': {
          _selectedCategory: int.tryParse(_quantityController.text.trim()) ?? 1,
        },
      });

        await donationRef.collection('items').add({
          'title': _titleController.text.trim(),
          'quantity': int.tryParse(_quantityController.text.trim()) ?? 1,
          'category': _selectedCategory,
        });

      // Create admin notification
      await FirebaseFirestore.instance.collection('admin_notifications').add({
        'type': 'donation',
        'title': 'New Donation from ${user.email}',
        'message': '${user.email} donated ${_titleController.text.trim()} - Category: $_selectedCategory - ${_selectedDeliveryOption}',
        'donorEmail': user.email,
        'donationId': donationRef.id,
        'categories': [_selectedCategory],
        'deliveryOption': _selectedDeliveryOption,
        'pickupStation': _selectedDeliveryOption == 'Pickup' ? _pickupStationController.text.trim() : null,
        'donorLocation': _detectedLocation ?? 'Unknown location',
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
      _showError('Failed to submit donation: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quantityController.dispose();
    _pickupStationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Make a Donation'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Improved Detected Location UI with Refresh Button
              Card(
                color: Colors.blue.shade50,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ListTile(
                  leading: _isDetectingLocation
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.location_on, color: Colors.blue),
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
              
              // Single Item Section
              Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Donation Item',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val ?? 'Clothes'),
                        decoration: const InputDecoration(
                          labelText: 'Category *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title *',
                          hintText: _categoryHints[_selectedCategory]?['title'] ?? '',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Enter title' : null,
                      ),
                      const SizedBox(height: 12),

                                              TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity *',
                            hintText: _categoryHints[_selectedCategory]?['quantity'] ?? '',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Enter quantity';
                            final num = int.tryParse(val);
                            if (num == null || num <= 0) return 'Enter a valid number';
                            return null;
                          },
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Delivery Option
              DropdownButtonFormField<String>(
                value: _selectedDeliveryOption,
                items: _deliveryOptions
                    .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDeliveryOption = value;
                    if (value == 'Drop-off') {
                      _pickupStationController.clear();
                    }
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Delivery Option',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? 'Please select a delivery option.' : null,
              ),
              
              const SizedBox(height: 16),
              
              if (_selectedDeliveryOption == 'Pickup') ...[
                TextFormField(
                  controller: _pickupStationController,
                  readOnly: true,
                  onTap: _handlePickupStationSelection,
                  decoration: const InputDecoration(
                    labelText: 'Pickup Station',
                    hintText: 'Tap to select pickup location',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.location_on),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please select a pickup station';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitDonation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
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