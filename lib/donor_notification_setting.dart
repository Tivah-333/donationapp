import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DonorNotificationSetting extends StatefulWidget {
  const DonorNotificationSetting({super.key});

  @override
  State<DonorNotificationSetting> createState() => _DonorNotificationSettingState();
}

class _DonorNotificationSettingState extends State<DonorNotificationSetting> {
  final user = FirebaseAuth.instance.currentUser;
  bool notificationsEnabled = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (doc.exists) {
      setState(() {
        notificationsEnabled = doc.data()?['notificationsEnabled'] ?? true;
        isLoading = false;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (user == null) return;
    setState(() {
      notificationsEnabled = value;
    });
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'notificationsEnabled': value,
    });
  }

  // Mark notification as read
  Future<void> _markAsRead(DocumentReference docRef) async {
    await docRef.update({'read': true});
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications'), backgroundColor: Colors.deepPurple),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.deepPurple,
        actions: [
          Row(
            children: [
              const Text('Enable'),
              Switch(
                value: notificationsEnabled,
                onChanged: _toggleNotifications,
              ),
            ],
          ),
        ],
      ),
      body: notificationsEnabled
          ? StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donor_notifications')
                  .where('donorId', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                
                // Sort by timestamp in memory (most recent first)
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
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isRead = data['read'] as bool? ?? false;
                    final timestamp = data['timestamp'] as Timestamp?;
                    final type = data['type'] as String? ?? 'general';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      color: isRead ? Colors.white : Colors.blue.shade50,
                      child: ListTile(
                        leading: _getNotificationIcon(type),
                        title: Text(
                          data['title'] ?? 'Notification',
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['message'] ?? ''),
                            if (timestamp != null)
                              Text(
                                DateFormat('MMM d, y h:mm a').format(timestamp.toDate()),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                        onTap: () {
                          if (!isRead) {
                            _markAsRead(doc.reference);
                          }
                          _handleNotificationTap(context, data);
                        },
                      ),
                    );
                  },
                );
              },
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Notifications are disabled',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _getNotificationIcon(String type) {
    switch (type) {
      case 'donation_status':
        return const Icon(Icons.favorite, color: Colors.red);
      case 'support_response':
        return const Icon(Icons.support_agent, color: Colors.blue);
      case 'donation_received_by_org':
        return const Icon(Icons.check_circle, color: Colors.green);
      default:
        return const Icon(Icons.notifications, color: Colors.orange);
    }
  }

  void _handleNotificationTap(BuildContext context, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    switch (type) {
      case 'donation_status':
        // Navigate to donation details or history
        Navigator.pushNamed(context, '/donor/history');
        break;
      case 'support_response':
        // Show support response details
        _showSupportResponseDialog(context, data);
        break;
      case 'donation_received_by_org':
        // Navigate to donation history
        Navigator.pushNamed(context, '/donor/history');
        break;
      default:
        // Show general notification details
        _showNotificationDetails(context, data);
        break;
    }
  }

  void _showSupportResponseDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] ?? 'Support Response'),
        content: Text(data['message'] ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] ?? 'Notification'),
        content: Text(data['message'] ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
