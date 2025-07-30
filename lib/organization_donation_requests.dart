import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OrganizationDonationRequestsPage extends StatefulWidget {
  const OrganizationDonationRequestsPage({Key? key}) : super(key: key);

  @override
  State<OrganizationDonationRequestsPage> createState() => _OrganizationDonationRequestsPageState();
}

class _OrganizationDonationRequestsPageState extends State<OrganizationDonationRequestsPage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Donation Requests'),
          backgroundColor: Colors.deepPurple,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Assigned'),
              Tab(text: 'Picked Up'),
              Tab(text: 'Dropped Off'),
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
            _buildRequestsList('picked_up'),
            _buildRequestsList('dropped_off'),
            _buildRequestsList('rejected'),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donation_requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];
        
        print('📋 Organization donation requests - Status: $status');
        print('📋 Total documents: ${allDocs.length}');
        
        // Filter manually to avoid index requirements
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final orgId = data['organizationId'];
          final docStatus = data['status'];
          
          print('  - Document ${doc.id}: orgId=$orgId, status=$docStatus, user=${user?.uid}');
          
          return orgId == user?.uid && docStatus == status;
        }).toList();
        
        print('📋 Filtered documents for status "$status": ${docs.length}');

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
                    ? 'Your assigned donations will appear here once they are assigned to your organization'
                    : status == 'picked_up'
                    ? 'Donations marked as picked up will appear here'
                    : status == 'dropped_off'
                    ? 'Donations marked as dropped off will appear here'
                    : 'Your donation requests will appear here once they reach this status',
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
                            color: _getStatusColor(data['status'] ?? status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            (data['status'] ?? status).toUpperCase(),
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
                      // Debug: Print all data for assigned requests
                      if (data['deliveryMethod'] == null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            'DEBUG: No delivery method found. Available data: ${data.keys.toList()}',
                            style: TextStyle(color: Colors.red[700], fontSize: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.notification_important, color: Colors.blue[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Donation Assignment Review Required',
                                    style: TextStyle(color: Colors.blue[700], fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A donation has been assigned to your organization. Please review the delivery method and approve or reject this assignment.',
                              style: TextStyle(color: Colors.blue[700], fontSize: 12),
                            ),
                            if (data['deliveryMethod'] != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      data['deliveryMethod'] == 'Pickup' ? Icons.local_shipping : Icons.location_on,
                                      color: Colors.orange[600],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Delivery Method: ${data['deliveryMethod']}',
                                        style: TextStyle(color: Colors.orange[700], fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (data['pickupStation'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Pickup Station: ${data['pickupStation']}',
                                style: TextStyle(color: Colors.orange[700], fontSize: 12),
                              ),
                            ],
                            if (data['donorLocation'] != null && data['donorLocation'] != 'Unknown location') ...[
                              const SizedBox(height: 4),
                              Text(
                                'Donor Location: ${data['donorLocation']}',
                                style: TextStyle(color: Colors.orange[700], fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _updateRequestStatus(doc.id, 'approved'),
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: const Text('Approve Assignment'),
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
                              label: const Text('Reject Assignment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (status == 'approved') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Assignment Approved',
                                    style: TextStyle(color: Colors.green[700], fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your donation assignment has been approved. Please mark the delivery status below.',
                              style: TextStyle(color: Colors.green[700], fontSize: 12),
                            ),
                            if (data['deliveryMethod'] != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      data['deliveryMethod'] == 'Pickup' ? Icons.local_shipping : Icons.location_on,
                                      color: Colors.blue[600],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Delivery Method: ${data['deliveryMethod']}',
                                        style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (data['deliveryMethod'] == 'Pickup') ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateRequestStatus(doc.id, 'picked_up'),
                                icon: const Icon(Icons.local_shipping, color: Colors.white),
                                label: const Text('Mark Picked Up'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ] else if (data['deliveryMethod'] == 'Drop-off') ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateRequestStatus(doc.id, 'dropped_off'),
                                icon: const Icon(Icons.location_on, color: Colors.white),
                                label: const Text('Mark Dropped Off'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
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
      print('🔄 Organization updating request $requestId to status: $newStatus');
      
      // Update the request status
      await FirebaseFirestore.instance
          .collection('donation_requests')
          .doc(requestId)
          .update({
        'status': newStatus,
        'organizationReviewedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Request status updated to: $newStatus');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assignment ${newStatus} successfully'),
            backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
        
        // Force a rebuild to refresh the lists
        setState(() {});
      }
    } catch (e) {
      print('❌ Error updating request status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update assignment: $e'),
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
      case 'picked_up':
        return Colors.blue;
      case 'dropped_off':
        return Colors.green;
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
      case 'picked_up':
        return Icons.local_shipping;
      case 'dropped_off':
        return Icons.location_on;
      default:
        return Icons.info;
    }
  }
} 