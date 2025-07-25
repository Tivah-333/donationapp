import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart'; // To get the ID token

class ApiService {
  final String _baseUrl = "https://your-api-base-url.cloudfunctions.net/api"; // <-- REPLACE WITH YOUR ACTUAL BASE URL
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Helper to get the Firebase ID Token for authentication
  Future<String?> _getIdToken() async {
    User? user = _firebaseAuth.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  // Helper to construct headers with Authorization token
  Future<Map<String, String>> _getHeaders() async {
    String? token = await _getIdToken();
    Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF--8',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // --- Donation Endpoints ---

  // GET /api/donations
  Future<List<dynamic>> getDonations({String? orgId, String? search}) async {
    try {
      Map<String, String> queryParams = {};
      if (orgId != null) queryParams['orgId'] = orgId;
      if (search != null) queryParams['search'] = search;

      final uri = Uri.parse('$_baseUrl/donations').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to load donations: ${response.statusCode} ${response.body}');
        throw Exception('Failed to load donations');
      }
    } catch (e) {
      print('Error in getDonations: $e');
      throw Exception('Failed to load donations: $e');
    }
  }

  // POST /api/donations
  Future<Map<String, dynamic>?> createDonation({
    required String item,
    required String description,
    required String category,
    Map<String, double>? location, // e.g., {'latitude': 34.0522, 'longitude': -118.2437}
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/donations'),
        headers: await _getHeaders(),
        body: jsonEncode(<String, dynamic>{
          'item': item,
          'description': description,
          'category': category,
          if (location != null) 'location': location,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) { // 201 is often used for created
        return jsonDecode(response.body);
      } else {
        print('Failed to create donation: ${response.statusCode} ${response.body}');
        throw Exception('Failed to create donation');
      }
    } catch (e) {
      print('Error in createDonation: $e');
      throw Exception('Failed to create donation: $e');
    }
  }

  // PUT /api/donations/:id
  Future<bool> updateDonation(String donationId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/donations/$donationId'),
        headers: await _getHeaders(),
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to update donation: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error in updateDonation: $e');
      return false;
    }
  }

  // DELETE /api/donations/:id
  Future<bool> deleteDonation(String donationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/donations/$donationId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to delete donation: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error in deleteDonation: $e');
      return false;
    }
  }
}
