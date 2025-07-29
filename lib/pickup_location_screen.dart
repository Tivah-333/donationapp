import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

const String kGoogleApiKey = 'AIzaSyA48TwKXXwt0-SfH9UQoMtMwRxsPggSUbs';

class PickupLocationScreen extends StatefulWidget {
  @override
  _PickupLocationScreenState createState() => _PickupLocationScreenState();
}

class _PickupLocationScreenState extends State<PickupLocationScreen> {
  Completer<GoogleMapController> _controller = Completer();
  LatLng? _pickedLocation;
  String? _pickedAddress;
  LocationData? _currentLocation;

  List<dynamic> _autocompleteResults = [];
  TextEditingController _searchController = TextEditingController();
  bool _showAutocomplete = false;
  bool _isLoadingAutocomplete = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    Location location = Location();
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    LocationData locationData = await location.getLocation();
    setState(() {
      _currentLocation = locationData;
      _pickedLocation = LatLng(locationData.latitude!, locationData.longitude!);
    });
  }

  Future<void> _autocompletePlaces(String input) async {
    if (input.isEmpty) {
      setState(() {
        _autocompleteResults = [];
        _showAutocomplete = false;
      });
      return;
    }
    setState(() {
      _isLoadingAutocomplete = true;
    });
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$kGoogleApiKey&components=country:ug',
    );
    final response = await http.get(url);
    print('Places API response: \n${response.body}'); // Debug print
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _autocompleteResults = data['predictions'];
        _showAutocomplete = true;
        _isLoadingAutocomplete = false;
      });
    } else {
      setState(() {
        _autocompleteResults = [];
        _showAutocomplete = false;
        _isLoadingAutocomplete = false;
      });
    }
  }

  Future<void> _selectAutocompletePlace(String placeId, String description) async {
    setState(() {
      _showAutocomplete = false;
      _searchController.text = description;
      _pickedAddress = description;
    });
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$kGoogleApiKey',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final location = data['result']['geometry']['location'];
      final lat = location['lat'];
      final lng = location['lng'];
      setState(() {
        _pickedLocation = LatLng(lat, lng);
      });
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLng(_pickedLocation!));
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _pickedLocation = position;
      _pickedAddress = null;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Pickup Location'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _currentLocation == null
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  initialCameraPosition: CameraPosition(
                    target: _pickedLocation ?? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  markers: {
                    if (_currentLocation != null)
                      Marker(
                        markerId: MarkerId('current-location'),
                        position: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                        infoWindow: InfoWindow(title: 'Your Location'),
                      ),
                    if (_pickedLocation != null)
                      Marker(
                        markerId: MarkerId('picked-location'),
                        position: _pickedLocation!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        infoWindow: InfoWindow(title: 'Pickup Location'),
                      ),
                  },
                  onTap: _onMapTap,
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for a location in Uganda',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: _autocompletePlaces,
                        ),
                      ),
                      if (_showAutocomplete)
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                              )
                            ],
                          ),
                          child: _isLoadingAutocomplete
                              ? Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _autocompleteResults.length,
                                  itemBuilder: (context, index) {
                                    final prediction = _autocompleteResults[index];
                                    return ListTile(
                                      title: Text(prediction['description']),
                                      onTap: () => _selectAutocompletePlace(prediction['place_id'], prediction['description']),
                                    );
                                  },
                                ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _pickedLocation == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                // Return a map with address and coordinates
                Navigator.pop(context, {
                  'address': _pickedAddress ?? _searchController.text,
                  'latlng': _pickedLocation,
                });
              },
              label: Text('Confirm Location'),
              icon: Icon(Icons.check),
              backgroundColor: Colors.deepPurple,
            ),
    );
  }
}