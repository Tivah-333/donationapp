import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OrgNotificationsPage extends StatefulWidget {
  const OrgNotificationsPage({Key? key}) : super(key: key);

  @override
  State<OrgNotificationsPage> createState() => _OrgNotificationsPageState();
}

class _OrgNotificationsPageState extends State<OrgNotificationsPage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('organization_notifications')
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
            return data['organizationId'] == user?.uid;
          }).toList();
          
          // Sort by timestamp manually
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['timestamp'] as Timestamp?;
            final bTime = bData['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Most recent first
          });

          if (docs.isEmpty) {
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
                  SizedBox(height: 8),
                  Text(
                    'You will see notifications here when you receive donations or updates',
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
              final isRead = data['read'] as bool? ?? false;

              return GestureDetector(
                onTap: () => _handleNotificationTap(doc.id, data),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? Colors.white : Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isRead ? Colors.grey.shade300 : Colors.blue.shade200, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _getNotificationIcon(data['type']),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? 'Notification',
                                    style: TextStyle(
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      fontSize: 16,
                                      color: isRead ? Colors.grey.shade700 : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy - HH:mm').format(
                                      (data['timestamp'] as Timestamp).toDate(),
                                    ),
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
                          data['message'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: isRead ? Colors.grey.shade700 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _getNotificationIcon(String? type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'donation_received':
        iconData = Icons.inventory;
        iconColor = Colors.green;
        break;
      case 'donation_request_status':
        iconData = Icons.assignment;
        iconColor = Colors.blue;
        break;
      case 'donation_assigned':
        iconData = Icons.local_shipping;
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
      await FirebaseFirestore.instance
          .collection('organization_notifications')
          .doc(notificationId)
          .update({
        'read': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  void _handleNotificationTap(String notificationId, Map<String, dynamic> data) {
    // Auto-mark as read when tapped
    _markAsRead(notificationId);
    
    // Handle different notification types
    final type = data['type'] as String?;
    switch (type) {
      case 'donation_received':
        // Navigate to donation details
        break;
      case 'donation_request_status':
        // Navigate to donation request details
        break;
      case 'support_response':
      case 'problem_response':
        // Show response details
        break;
      default:
        // For other notification types, just mark as read
        break;
    }
  }
}
