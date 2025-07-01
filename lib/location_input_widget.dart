import 'package:flutter/material.dart';

class LocationInputWidget extends Statefulwidget {
  const LocationInputWidget({Key? key}) : super(key: key);

  @override
  State<LocationInputWidget> createState() => _LocationInputWidgetState();
}

class _LocationInputWidgetState extends State<LocationInputWidget> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _donorLocationController = TextEditingController();
  final TextEditingController _pickupStationController = TextEditingController();

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final donorLocation = _donorLocationController.text;
      final pickupStation = _pickupStationController.text;

      // For now, show a dialog with the entered data
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location Info'),
          content: Text(
              'Donor Location: $donorLocation\nPick-up Station: $pickupStation'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );

      // You can later save these to Firebase or send them to your backend.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _donorLocationController,
            decoration: const InputDecoration(
              labelText: 'Donor Location',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the donor location';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pickupStationController,
            decoration: const InputDecoration(
              labelText: 'Pick-up Station',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the pick-up station';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: _submitForm,
              icon: const Icon(Icons.send),
              label: const Text('Submit Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
