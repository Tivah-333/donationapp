import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class IssueReportDetailsPage extends StatefulWidget {
  final String problemDocId;

  const IssueReportDetailsPage({Key? key, required this.problemDocId})
      : super(key: key);

  @override
  State<IssueReportDetailsPage> createState() => _IssueReportDetailsPageState();
}

class _IssueReportDetailsPageState extends State<IssueReportDetailsPage> {
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
          .collection('problems')
          .doc(widget.problemDocId)
          .get();

      if (!doc.exists) {
        _showError('Problem report not found.');
        return;
      }

      setState(() {
        _problemData = doc.data();
        _responseController.text = _problemData?['response'] ?? '';
        _isLoading = false;
      });

      await _markNotificationAsRead();
    } catch (e) {
      _showError('Failed to load problem: ${e.toString()}');
    }
  }

  Future<void> _markNotificationAsRead() async {
    try {
      final notifications = await FirebaseFirestore.instance
          .collection('admin_notifications')
          .where('problemId', isEqualTo: widget.problemDocId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {
          'read': true,
          'status': 'resolved',
        });
      }
      await batch.commit();
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
      final response = _responseController.text.trim();
      final now = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('problems')
          .doc(widget.problemDocId)
          .update({
        'response': response,
        'isResponded': true,
        'responseTimestamp': now,
        'status': 'resolved',
      });

      await _updateRelatedNotifications(response, now);

      _showSuccess('Response submitted successfully');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Failed to submit response: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _updateRelatedNotifications(String response, dynamic timestamp) async {
    final notifications = await FirebaseFirestore.instance
        .collection('admin_notifications')
        .where('problemId', isEqualTo: widget.problemDocId)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in notifications.docs) {
      batch.update(doc.reference, {
        'response': response,
        'responseTimestamp': timestamp,
        'status': 'resolved',
        'read': true,
      });
    }
    await batch.commit();

    // Send notification to the user who reported the problem
    final userId = _problemData?['userId'];
    final userType = _problemData?['userType'];
    final userEmail = _problemData?['userEmail'];

    if (userId != null && userType != null) {
      try {
        if (userType == 'donor') {
          await FirebaseFirestore.instance.collection('donor_notifications').add({
            'donorId': userId,
            'type': 'problem_response',
            'title': 'Issue Report Response',
            'message': 'You have received a response to your issue report: $response',
            'timestamp': timestamp,
            'read': false,
            'adminResponse': response,
            'originalIssue': _problemData?['message'] ?? 'No message provided',
            'issueType': 'problem_report',
          });
        } else if (userType == 'organization') {
          await FirebaseFirestore.instance.collection('organization_notifications').add({
            'organizationId': userId,
            'type': 'problem_response',
            'title': 'Issue Report Response',
            'message': 'You have received a response to your issue report: $response',
            'timestamp': timestamp,
            'read': false,
            'adminResponse': response,
            'originalIssue': _problemData?['message'] ?? 'No message provided',
            'issueType': 'problem_report',
          });
        }
        print('✅ Notification sent to $userType: $userEmail');
      } catch (e) {
        print('❌ Error sending notification to user: $e');
      }
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
        actions: [
          if (_problemData?['isResponded'] ?? false)
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
                  'Problem reported by ${_problemData!['userEmail'] ?? 'Unknown'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Role: ${(_problemData!['userType'] ?? 'user').toString().toUpperCase()}',
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
            if ((_problemData!['message'] ?? '').isNotEmpty) ...[
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
                _problemData!['message']!,
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
                'Responded on: ${_formatTimestamp(_problemData!['responseTimestamp'] as Timestamp?)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
            ],

            if (!(_problemData!['isResponded'] ?? false)) ...[
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