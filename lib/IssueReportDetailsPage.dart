import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

class IssueReportDetailsPage extends StatefulWidget {
  final String problemDocId;

  const IssueReportDetailsPage({Key? key, required this.problemDocId}) : super(key: key);

  @override
  State<IssueReportDetailsPage> createState() => _IssueReportDetailsPageState();
}

class _IssueReportDetailsPageState extends State<IssueReportDetailsPage> {
  final String apiUrl = 'http://127.0.0.1:5001/donationapp-3c/us-central1/api';
  final TextEditingController _responseController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _problemData;

  @override
  void initState() {
    super.initState();
    _loadProblemDetails();
  }

  Future<void> _loadProblemDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('issues')
          .doc(widget.problemDocId)
          .get();

      if (!doc.exists) {
        _showError('Issue report not found.');
        return;
      }

      setState(() {
        _problemData = doc.data();
        _responseController.text = _problemData?['response'] ?? '';
        _isLoading = false;
      });

      await _markNotificationAsRead();
    } catch (e) {
      _showError('Failed to load issue: $e');
    }
  }

  Future<void> _markNotificationAsRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$apiUrl/notifications?recipientId=${user.uid}&issueId=${widget.problemDocId}'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (response.statusCode == 200) {
        final notifications = jsonDecode(response.body) as List;
        final batch = FirebaseFirestore.instance.batch();
        for (var notif in notifications) {
          batch.update(
            FirebaseFirestore.instance.collection('notifications').doc(notif['id']),
            {'read': true},
          );
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _submitResponse() async {
    if (_responseController.text.trim().isEmpty) {
      _showError('Please enter a response');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();
      final response = await http.put(
        Uri.parse('$apiUrl/support/issues/${widget.problemDocId}/respond'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'response': _responseController.text.trim(),
          'status': 'resolved',
        }),
      );
      if (response.statusCode == 200) {
        _showSuccess('Response submitted successfully');
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception('Failed to submit response: ${response.body}');
      }
    } catch (e) {
      _showError('Failed to submit response: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
    if (message.contains('not found') && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'Unknown time';
    return DateFormat('MMM d, y • h:mm a').format(ts.toDate());
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Report Details'),
        backgroundColor: Colors.deepPurple,
        actions: [
          if (_problemData?['status'] == 'resolved')
            const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _problemData == null
          ? const Center(child: Text('No data available'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Issue reported by ${_problemData!['email'] ?? 'Unknown'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Role: ${(_problemData!['role'] ?? 'user').toString().toUpperCase()}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reported on: ${_formatTimestamp(_problemData!['timestamp'] as Timestamp?)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if ((_problemData!['description'] ?? '').isNotEmpty) ...[
              const Text(
                'ISSUE DETAILS:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _problemData!['description']!,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
            ],

            if ((_problemData!['imageUrl'] ?? '').isNotEmpty) ...[
              Image.network(_problemData!['imageUrl']),
              const SizedBox(height: 20),
            ],

            if ((_problemData!['response'] ?? '').isNotEmpty) ...[
              const Text(
                'ADMIN RESPONSE:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _problemData!['response'],
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Responded on: ${_formatTimestamp(_problemData!['updatedAt'] as Timestamp?)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
            ],

            if (_problemData!['status'] != 'resolved') ...[
              const Text(
                'YOUR RESPONSE:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _responseController,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter your response here...',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitResponse,
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                      : const Text('SUBMIT RESPONSE'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}