import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DonorNotificationsPage extends StatefulWidget {
  const DonorNotificationsPage({Key? key}) : super(key: key);

  @override
  State<DonorNotificationsPage> createState() => _DonorNotificationsPageState();
}

class _DonorNotificationsPageState extends State<DonorNotificationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index].data() as Map<String, dynamic>;
              final notificationId = notifications[index].id;
              final isRead = notification['read'] ?? false;
              final type = notification['type'] ?? 'general';
              final requiresAction = notification['requiresAction'] ?? false;

              return _buildNotificationCard(
                notificationId,
                notification,
                isRead,
                type,
                requiresAction,
              );
            },
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getNotificationsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('donor_notifications')
        .where('donorId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Widget _buildNotificationCard(
    String notificationId,
    Map<String, dynamic> notification,
    bool isRead,
    String type,
    bool requiresAction,
  ) {
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final timestamp = notification['timestamp'] as Timestamp?;
    final formattedTime = timestamp != null
        ? DateFormat('MMM dd, yyyy - HH:mm').format(timestamp.toDate())
        : 'Unknown time';

    Color cardColor = isRead ? Colors.white : Colors.blue.shade50;
    Color borderColor = isRead ? Colors.grey.shade300 : Colors.blue.shade200;

    return GestureDetector(
      onTap: () => _handleNotificationTap(notificationId, notification),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _getNotificationIcon(type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 16,
                            color: isRead ? Colors.grey.shade700 : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: isRead ? Colors.grey.shade700 : Colors.black87,
                ),
              ),
              if (requiresAction) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleAction(notificationId, 'accept', notification),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleAction(notificationId, 'reject', notification),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              // Remove the "Mark as Read" button - notifications are auto-marked when tapped
            ],
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(String notificationId, Map<String, dynamic> notification) {
    final type = notification['type'] as String?;
    
    // Auto-mark as read when tapped for ALL notification types
    if (notificationId.isNotEmpty) {
      _markAsRead(notificationId);
    }
    
    switch (type) {
      case 'donation_status':
        _showDonationDetails(notification);
        break;
      case 'support_response':
      case 'problem_response':
        _showResponseDetails(notification);
        break;
      case 'dropoff_assignment':
        // Don't show details for dropoff assignment as it has action buttons
        break;
      default:
        // For other notification types, just mark as read (already done above)
        break;
    }
  }

  Widget _getNotificationIcon(String type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'dropoff_assignment':
        iconData = Icons.location_on;
        iconColor = Colors.orange;
        break;
      case 'support_response':
        iconData = Icons.support_agent;
        iconColor = Colors.blue;
        break;
      case 'problem_response':
        iconData = Icons.report_problem;
        iconColor = Colors.red;
        break;
      case 'donation_status':
        iconData = Icons.local_shipping;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('donor_notifications')
          .doc(notificationId)
          .update({'read': true});
      
      // No SnackBar needed for auto-marking
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleAction(String notificationId, String action, Map<String, dynamic> notification) async {
    try {
      // Mark notification as read
      await _markAsRead(notificationId);

      // Handle the action based on notification type
      final type = notification['type'];
      
      if (type == 'dropoff_assignment') {
        await _handleDropoffAssignment(action, notification);
      } else if (type == 'donation_status') {
        await _showDonationDetails(notification);
      } else if (type == 'support_response' || type == 'problem_response') {
        await _showResponseDetails(notification);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action $action completed successfully'),
            backgroundColor: action == 'accept' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error handling action: $e')),
        );
      }
    }
  }

  Future<void> _showDonationDetails(Map<String, dynamic> notification) async {
    final donationId = notification['donationId'];
    final donationTitle = notification['donationTitle'];
    final donationCategory = notification['donationCategory'];
    final organizationName = notification['organizationName'];
    final deliveryMethod = notification['deliveryMethod'];
    final pickupStation = notification['pickupStation'];
    final donorLocation = notification['donorLocation'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Donation Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (donationTitle != null) Text('Title: $donationTitle'),
            if (donationCategory != null) Text('Category: $donationCategory'),
            if (organizationName != null) Text('Assigned to: $organizationName'),
            if (deliveryMethod != null) Text('Delivery Method: $deliveryMethod'),
            if (pickupStation != null) Text('Pickup Station: $pickupStation'),
            if (donorLocation != null) Text('Location: $donorLocation'),
            // Removed donation ID from display
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResponseDetails(Map<String, dynamic> notification) async {
    final adminResponse = notification['adminResponse'];
    final originalRequest = notification['originalRequest'] ?? notification['originalIssue'];
    final issueType = notification['issueType'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Response Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (originalRequest != null) ...[
              Text(
                'Your ${issueType == 'problem_report' ? 'Issue Report' : 'Support Request'}:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(originalRequest),
              SizedBox(height: 16),
            ],
            Text(
              'Admin Response:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(adminResponse ?? 'No response provided'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDropoffAssignment(String action, Map<String, dynamic> notification) async {
    final donationId = notification['donationId'];
    final organizationName = notification['organizationName'];
    
    if (action == 'accept') {
      // Update donation status to accepted
      await _firestore.collection('donations').doc(donationId).update({
        'donorAccepted': true,
        'donorAcceptedAt': FieldValue.serverTimestamp(),
      });
      
      // Send notification to organization
      await _firestore.collection('organization_notifications').add({
        'organizationId': notification['organizationId'],
        'type': 'donor_accepted',
        'title': 'Donor Accepted Assignment',
        'message': 'The donor has accepted the donation assignment. You can proceed with pickup/delivery.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'donationId': donationId,
      });
      
    } else if (action == 'reject') {
      // Update donation status to rejected
      await _firestore.collection('donations').doc(donationId).update({
        'donorRejected': true,
        'donorRejectedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // Reset to pending for reassignment
        'assignedTo': null,
      });
      
      // Send notification to organization
      await _firestore.collection('organization_notifications').add({
        'organizationId': notification['organizationId'],
        'type': 'donor_rejected',
        'title': 'Donor Rejected Assignment',
        'message': 'The donor has rejected the donation assignment due to distance. The donation will be reassigned.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'donationId': donationId,
      });
    }
  }
} 