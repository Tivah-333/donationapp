import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'services/notification_service.dart';

class AdminDonationRequestsPage extends StatefulWidget {
  const AdminDonationRequestsPage({Key? key}) : super(key: key);

  @override
  State<AdminDonationRequestsPage> createState() => _AdminDonationRequestsPageState();
}

class _AdminDonationRequestsPageState extends State<AdminDonationRequestsPage> {
  final Map<String, DateTime> _lastRefresh = {};
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Donation Requests'),
          backgroundColor: Colors.deepPurple,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _lastRefresh['pending'] = DateTime.now();
                  _lastRefresh['approved'] = DateTime.now();
                  _lastRefresh['assigned'] = DateTime.now();
                  _lastRefresh['rejected'] = DateTime.now();
                });
                print('🔄 Manual refresh triggered');
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Assigned'),
              Tab(text: 'Rejected'),
            ],
            indicatorColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequestsList('pending'),
            _buildRequestsList('approved'),
            _buildRequestsList('assigned'),
            _buildRequestsList('rejected'),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList(String status) {
    return FutureBuilder<QuerySnapshot>(
      future: _getRequestsForStatus(status),
      builder: (context, snapshot) {
        print('📋 FutureBuilder for status "$status": ${snapshot.data?.docs.length ?? 0} documents');
        
        if (snapshot.hasError) {
          print('❌ FutureBuilder error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        print('📋 Found ${docs.length} requests with status: $status');

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getStatusIcon(status), size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No $status donation requests',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  status == 'assigned' 
                    ? 'Assigned donation requests will appear here once donations are assigned to organizations'
                    : 'Donation requests will appear here once organizations submit them',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            print('📋 Request ${doc.id}: status = ${data['status']}, title = ${data['title']}');

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title'] ?? 'Untitled Request',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Organization: ${data['organizationEmail'] ?? 'Unknown'}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Organization Name: ${data['organizationName'] ?? 'Unknown'}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Category: ${data['category'] ?? 'Unknown'}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Quantity: ${data['quantity'] ?? 0}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Location: ${data['location'] ?? 'Unknown location'}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              if (data['deliveryOption'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Delivery: ${data['deliveryOption']}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Date: ${DateFormat('MMM d, y h:mm a').format((data['timestamp'] as Timestamp).toDate())}',
                                style: TextStyle(color: Colors.grey),
                              ),
                              if (status == 'assigned' && data['assignedAt'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Assigned: ${DateFormat('MMM d, y h:mm a').format((data['assignedAt'] as Timestamp).toDate())}',
                                  style: TextStyle(color: Colors.green[600], fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (data['description'] != null && data['description'].isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Description:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['description'],
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                    if (status == 'assigned') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This donation request has been assigned to the organization. The donation has been matched and assigned.',
                                style: TextStyle(color: Colors.green[700], fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (status == 'pending') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _updateRequestStatus(doc.id, 'approved'),
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _updateRequestStatus(doc.id, 'rejected'),
                              icon: const Icon(Icons.close, color: Colors.white),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      print('🔄 Updating request $requestId to status: $newStatus');
      
      // Get the request data first
      final requestDoc = await FirebaseFirestore.instance
          .collection('donation_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      final organizationId = requestData['organizationId'] as String?;
      final organizationEmail = requestData['organizationEmail'] as String?;

      print('📋 Current request data: $requestData');

      // Update the request status
      await FirebaseFirestore.instance
          .collection('donation_requests')
          .doc(requestId)
          .update({
        'status': newStatus,
        'processedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Request status updated to: $newStatus');

      // Send notification to the organization
      if (organizationId != null && organizationEmail != null) {
        await NotificationService.sendDonationRequestStatusNotification(
          organizationId: organizationId,
          organizationEmail: organizationEmail,
          status: newStatus,
          requestTitle: requestData['title'] as String? ?? 'Unknown',
          requestCategory: requestData['category'] as String? ?? 'Unknown',
        );
        print('📧 Notification sent to: $organizationEmail');
      }

      if (mounted) {
        // Force refresh of the lists
        setState(() {
          _lastRefresh['pending'] = DateTime.now();
          _lastRefresh['approved'] = DateTime.now();
          _lastRefresh['assigned'] = DateTime.now();
          _lastRefresh['rejected'] = DateTime.now();
        });
        
        // Add a simple test to verify the update worked
        print('🔄 Status update completed. Checking if document was updated...');
        final updatedDoc = await FirebaseFirestore.instance
            .collection('donation_requests')
            .doc(requestId)
            .get();
        
        if (updatedDoc.exists) {
          final updatedData = updatedDoc.data()!;
          print('✅ Document updated successfully! New status: ${updatedData['status']}');
        } else {
          print('❌ Document not found after update!');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request ${newStatus} successfully'),
            backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating request status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'assigned':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'approved':
        return Icons.check_circle;
      case 'assigned':
        return Icons.assignment_turned_in;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Future<QuerySnapshot> _getRequestsForStatus(String status) async {
    print('🔄 Fetching requests for status: $status');
    final snapshot = await FirebaseFirestore.instance
        .collection('donation_requests')
        .where('status', isEqualTo: status)
        .orderBy('timestamp', descending: true)
        .get();
    
    print('📋 Retrieved ${snapshot.docs.length} requests for status: $status');
    for (final doc in snapshot.docs) {
      final data = doc.data();
      print('  - ${doc.id}: ${data['title']} (${data['status']})');
    }
    
    return snapshot;
  }
} 