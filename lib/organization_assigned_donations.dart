import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'donation_details_screen.dart';
import 'services/notification_service.dart';

class OrganizationAssignedDonationsPage extends StatefulWidget {
  const OrganizationAssignedDonationsPage({Key? key}) : super(key: key);

  @override
  State<OrganizationAssignedDonationsPage> createState() => _OrganizationAssignedDonationsPageState();
}

class _OrganizationAssignedDonationsPageState extends State<OrganizationAssignedDonationsPage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Assigned Donations'),
          backgroundColor: Colors.deepPurple,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Assigned'),
              Tab(text: 'Picked Up'),
              Tab(text: 'Dropped Off'),
            ],
            indicatorColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: [
            _buildDonationsList('approved'),
            _buildDonationsList('picked_up'),
            _buildDonationsList('dropped_off'),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];
        
        // Filter manually to avoid index requirements
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final docStatus = data['status'] as String?;
          
          return data['assignedTo'] == user?.uid && docStatus == status;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getStatusIcon(status), size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No ${status.replaceAll('_', ' ')} donations',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Donations will appear here once they reach this status',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
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
                                'Donation from ${data['donorEmail'] ?? 'Unknown'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Date: ${DateFormat('MMM d, y h:mm a').format((data['timestamp'] as Timestamp).toDate())}',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text('Location: ${data['location'] ?? 'Unknown'}'),
                    Text('Delivery: ${data['deliveryOption'] ?? 'Unknown'}'),
                    if (data['pickupStation'] != null)
                      Text('Pickup Station: ${data['pickupStation']}'),
                    SizedBox(height: 12),
                    Text(
                      'Categories:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: (data['categories'] as List<dynamic>? ?? []).map((category) {
                        return Chip(
                          label: Text(category.toString()),
                          backgroundColor: Colors.blue.shade100,
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _viewDetails(context, doc.id),
                            icon: Icon(Icons.visibility),
                            label: Text('View Details'),
                          ),
                        ),
                        SizedBox(width: 12),
                        if (status == 'approved')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _markAsPickedUp(context, doc.id),
                              icon: Icon(Icons.local_shipping, color: Colors.white),
                              label: Text(_getActionButtonText(data['deliveryOption'])),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        if (status == 'picked_up' && data['deliveryOption'] == 'Drop-off')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _markAsDroppedOff(context, doc.id),
                              icon: Icon(Icons.check_circle, color: Colors.white),
                              label: Text('Mark Dropped Off'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.blue;
      case 'picked_up':
        return Colors.orange;
      case 'dropped_off':
        return Colors.green;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.assignment;
      case 'picked_up':
        return Icons.local_shipping;
      case 'dropped_off':
        return Icons.check_circle;
      case 'delivered':
        return Icons.check_circle;
      default:
        return Icons.inbox;
    }
  }

  void _viewDetails(BuildContext context, String donationId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DonationDetailsPage(donationId: donationId),
      ),
    );
  }

  Future<void> _markAsPickedUp(BuildContext context, String donationId) async {
    try {
      // Get donation data first
      final donationDoc = await FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId)
          .get();
      
      if (!donationDoc.exists) {
        throw Exception('Donation not found');
      }

      final donationData = donationDoc.data()!;
      final donorId = donationData['donorId'] as String?;
      final donorEmail = donationData['donorEmail'] as String?;
      final deliveryOption = donationData['deliveryOption'] as String?;

      // Determine the correct status based on delivery option
      String newStatus;
      String notificationMessage;
      
      if (deliveryOption == 'Pickup') {
        newStatus = 'picked_up';
        notificationMessage = 'Donation marked as picked up';
      } else if (deliveryOption == 'Drop-off') {
        // For drop-off, mark as picked up first, then they can mark as dropped off
        newStatus = 'picked_up';
        notificationMessage = 'Donation marked as picked up';
      } else {
        newStatus = 'picked_up';
        notificationMessage = 'Donation marked as picked up';
      }

      // Update donation status and track which organization processed it
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': newStatus,
        'pickedUpAt': FieldValue.serverTimestamp(),
        'processedBy': user?.uid, // Track which organization processed this donation
      });

      // Send notification to donor
      if (donorId != null && donorEmail != null) {
        await NotificationService.sendDonationStatusNotification(
          donationId: donationId,
          status: newStatus,
          recipientId: donorId,
          recipientType: 'donor',
          donorEmail: donorEmail,
          donationTitle: donationData['title'] as String?,
          donationCategory: donationData['category'] as String?,
          deliveryMethod: donationData['deliveryOption'] as String?,
          pickupStation: donationData['pickupStation'] as String?,
          donorLocation: donationData['location'] as String?,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notificationMessage)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _markAsDroppedOff(BuildContext context, String donationId) async {
    try {
      // Get donation data first
      final donationDoc = await FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId)
          .get();
      
      if (!donationDoc.exists) {
        throw Exception('Donation not found');
      }

      final donationData = donationDoc.data()!;
      final donorId = donationData['donorId'] as String?;
      final donorEmail = donationData['donorEmail'] as String?;

      // Update donation status to dropped off and track which organization processed it
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'dropped_off',
        'droppedOffAt': FieldValue.serverTimestamp(),
        'processedBy': user?.uid, // Track which organization processed this donation
      });

      // Send notification to donor
      if (donorId != null && donorEmail != null) {
        await NotificationService.sendDonationStatusNotification(
          donationId: donationId,
          status: 'dropped_off',
          recipientId: donorId,
          recipientType: 'donor',
          donorEmail: donorEmail,
          donationTitle: donationData['title'] as String?,
          donationCategory: donationData['category'] as String?,
          deliveryMethod: donationData['deliveryOption'] as String?,
          pickupStation: donationData['pickupStation'] as String?,
          donorLocation: donationData['location'] as String?,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Donation marked as dropped off')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as dropped off: $e')),
        );
      }
    }
  }

  Future<void> _markAsDelivered(BuildContext context, String donationId) async {
    try {
      // Get donation data first
      final donationDoc = await FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId)
          .get();
      
      if (!donationDoc.exists) {
        throw Exception('Donation not found');
      }

      final donationData = donationDoc.data()!;
      final donorId = donationData['donorId'] as String?;
      final donorEmail = donationData['donorEmail'] as String?;

      // Update donation status
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });

      // Send notification to donor
      if (donorId != null && donorEmail != null) {
        await NotificationService.sendDonationStatusNotification(
          donationId: donationId,
          status: 'delivered',
          recipientId: donorId,
          recipientType: 'donor',
          donorEmail: donorEmail,
          donationTitle: donationData['title'] as String?,
          donationCategory: donationData['category'] as String?,
          deliveryMethod: donationData['deliveryOption'] as String?,
          pickupStation: donationData['pickupStation'] as String?,
          donorLocation: donationData['location'] as String?,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Donation marked as delivered')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as delivered: $e')),
        );
      }
    }
  }

  String _getActionButtonText(String? deliveryOption) {
    if (deliveryOption == 'Pickup') {
      return 'Mark Picked Up';
    } else if (deliveryOption == 'Drop-off') {
      return 'Mark Picked Up';
    }
    return 'Mark Picked Up';
  }

  String _getFinalActionButtonText(String? deliveryOption) {
    if (deliveryOption == 'Pickup') {
      return 'Mark Delivered';
    } else if (deliveryOption == 'Drop-off') {
      return 'Mark Delivered';
    }
    return 'Mark Completed';
  }
} 