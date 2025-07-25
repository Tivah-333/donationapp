import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';


class PickupStationMapPicker extends StatefulWidget {
  const PickupStationMapPicker({Key? key}) : super(key: key);

  @override
  _PickupStationMapPickerState createState() => _PickupStationMapPickerState();
}

class _PickupStationMapPickerState extends State<PickupStationMapPicker> {
  LatLng? _pickedLocation;
  String? _address;

  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Pickup Station Location'),
        backgroundColor: const Color(0xFF6A1B9A),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 2,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: (latLng) async {
              setState(() {
                _pickedLocation = latLng;
                _address = 'Loading...';
              });

              try {
                List<Placemark> placemarks =
                await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
                if (placemarks.isNotEmpty) {
                  final place = placemarks.first;
                  final formattedAddress =
                      '${place.name}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
                  setState(() {
                    _address = formattedAddress;
                  });
                } else {
                  setState(() {
                    _address = 'No address found';
                  });
                }
              } catch (e) {
                setState(() {
                  _address = 'Error retrieving address';
                });
              }
            },
            markers: _pickedLocation != null
                ? {
              Marker(
                markerId: const MarkerId('picked-location'),
                position: _pickedLocation!,
              )
            }
                : {},
          ),
          if (_address != null)
            Positioned(
              bottom: 30,
              left: 10,
              right: 10,
              child: Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_address ?? '', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A)),
                        onPressed: () {
                          if (_address != null && _pickedLocation != null) {
                            Navigator.pop(context, _address);
                          }
                        },
                        child: const Text('Confirm Location'),
                      )
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
