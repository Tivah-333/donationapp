import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum NotificationFilter { today, lastWeek, lastMonth }

class OrgNotificationsPage extends StatefulWidget {
  const OrgNotificationsPage({super.key});

  @override
  State<OrgNotificationsPage> createState() => _OrgNotificationsPageState();
}

class _OrgNotificationsPageState extends State<OrgNotificationsPage> {
  final user = FirebaseAuth.instance.currentUser;
  bool notificationsEnabled = true;
  bool isLoading = true;
  NotificationFilter filter = NotificationFilter.today;

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

  DateTime _getFilterStartDate() {
    final now = DateTime.now();
    switch (filter) {
      case NotificationFilter.today:
        return DateTime(now.year, now.month, now.day);
      case NotificationFilter.lastWeek:
        return now.subtract(const Duration(days: 7));
      case NotificationFilter.lastMonth:
        return DateTime(now.year, now.month - 1, now.day);
    }
  }

  // Mark notification as read
  Future<void> _markAsRead(DocumentReference docRef) async {
    await docRef.update({'read': true});
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Notifications')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final startDate = _getFilterStartDate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
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
          ? Column(
        children: [
          // Filter dropdown
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<NotificationFilter>(
              value: filter,
              items: const [
                DropdownMenuItem(
                  value: NotificationFilter.today,
                  child: Text('Today'),
                ),
                DropdownMenuItem(
                  value: NotificationFilter.lastWeek,
                  child: Text('Last Week'),
                ),
                DropdownMenuItem(
                  value: NotificationFilter.lastMonth,
                  child: Text('Last Month'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    filter = value;
                  });
                }
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: user!.uid)
                  .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No notifications.'));
                }

                final notifications = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final title = notification['title'] ?? 'No Title';
                    final message = notification['message'] ?? '';
                    final timestamp = (notification['timestamp'] as Timestamp).toDate();
                    final read = notification['read'] ?? false;
                    final docRef = notification.reference;

                    return ListTile(
                      leading: Icon(
                        read ? Icons.mark_email_read : Icons.mark_email_unread,
                        color: read ? Colors.grey : Colors.blue,
                      ),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(message),
                      trailing: Text(
                        '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      tileColor: read ? Colors.grey[200] : null,
                      onTap: () async {
                        if (!read) {
                          await _markAsRead(docRef);
                        }
                        // Optionally show details or do something here
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      )
          : Center(
        child: Text(
          'Notifications are disabled.\nYou will not receive new notifications.',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
