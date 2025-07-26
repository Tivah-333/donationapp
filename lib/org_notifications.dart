import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'IssueReportDetailsPage.dart';

enum NotificationFilter { today, lastWeek, lastMonth }

class OrgNotificationsPage extends StatefulWidget {
  const OrgNotificationsPage({super.key});

  @override
  State<OrgNotificationsPage> createState() => _OrgNotificationsPageState();
}

class _OrgNotificationsPageState extends State<OrgNotificationsPage> {
  final String apiUrl = 'http://127.0.0.1:5001/donationapp-3c/us-central1/api';
  bool notificationsEnabled = true;
  bool isLoading = true;
  NotificationFilter filter = NotificationFilter.today;

  @override
  void initState() {
  super.initState();
  _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
  final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (doc.exists) {
  setState(() {
  notificationsEnabled = doc.data()?['notificationsEnabled'] ?? true;
  isLoading = false;
  });
  }
  } catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Error loading preferences: $e')),
  );
  setState(() => isLoading = false);
  }
  }

  Future<void> _toggleNotifications(bool value) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  setState(() {
  notificationsEnabled = value;
  });
  try {
  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
  'notificationsEnabled': value,
  });
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
  content: Text(notificationsEnabled ? 'Notifications enabled' : 'Notifications disabled'),
  duration: const Duration(seconds: 2),
  ),
  );
  } catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Error saving preference: $e')),
  );
  setState(() {
  notificationsEnabled = !value;
  });
  }
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

  Future<void> _markAsRead(String notificationId) async {
  try {
  await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({
  'read': true,
  });
  } catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Error marking as read: $e')),
  );
  }
  }

  Future<void> _navigateToDetails(String type, String? donationId, String? issueId) async {
  if (type == 'issue_report' && issueId != null) {
  Navigator.push(
  context,
  MaterialPageRoute(
  builder: (context) => IssueReportDetailsPage(problemDocId: issueId),
  ),
  );
  } else if (type == 'donation' && donationId != null) {
  await _showDonationDetails(donationId);
  }
  }

  Future<void> _showDonationDetails(String donationId) async {
  try {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('User not authenticated');
  final idToken = await user.getIdToken();
  final response = await http.get(
  Uri.parse('$apiUrl/donations/$donationId'),
  headers: {'Authorization': 'Bearer $idToken'},
  );
  if (response.statusCode == 200) {
  final donation = jsonDecode(response.body);
  if (mounted) {
  showDialog(
  context: context,
  builder: (context) => AlertDialog(
  title: const Text('Donation Details'),
  content: SingleChildScrollView(
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
  Text('Status: ${donation['status'] ?? 'Pending'}'),
  const SizedBox(height: 8),
  Text('Items:'),
  for (var item in donation['item'] ?? []) ...[
  Text('- ${item['item']} (${item['quantity']} units, ${item['category']})'),
  Text('  Description: ${item['description']}'),
  ],
  const SizedBox(height: 8),
  Text('Delivery Option: ${donation['deliveryOption'] ?? 'N/A'}'),
  if (donation['pickupStation'] != null)
  Text('Pickup Station: ${donation['pickupStation']}'),
  Text('Location: ${donation['locationName'] ?? 'Unknown'}'),
  Text('Created: ${_formatTimestamp(Timestamp.fromDate(DateTime.parse(donation['timestamp'])))}'),
  ],
  ),
  ),
  actions: [
  TextButton(
  onPressed: () => Navigator.pop(context),
  child: const Text('Close'),
  ),
  ],
  ),
  );
  }
  } else {
  throw Exception('Failed to load donation details: ${response.body}');
  }
  } catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Error: $e')),
  );
  }
  }

  Icon _getIconForType(String type, bool read) {
  final color = read ? Colors.grey : Colors.blue;
  switch (type) {
  case 'issue_report':
  return Icon(Icons.report_problem, color: color);
  case 'donation':
  return Icon(Icons.volunteer_activism, color: color);
  case 'support_response':
  return Icon(Icons.support, color: color);
  case 'donation_request':
  return Icon(Icons.request_page, color: color);
  case 'issue_status_change':
  return Icon(Icons.update, color: color);
  default:
  return Icon(Icons.notifications, color: color);
  }
  }

  String _formatTimestamp(Timestamp? ts) {
  if (ts == null) return 'Unknown time';
  return DateFormat('MMM d, y • h:mm a').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
  if (isLoading) {
  return Scaffold(
  appBar: AppBar(title: const Text('Notifications'), backgroundColor: Colors.deepPurple),
  body: const Center(child: CircularProgressIndicator()),
  );
  }

  final startDate = _getFilterStartDate();

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
      .where('recipientId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
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
  final timestamp = (notification['timestamp'] as Timestamp?)?.toDate();
  final read = notification['read'] ?? false;
  final notificationId = notification.id;
  final type = notification['type'] ?? 'unknown';
  final donationId = notification['donationId'];
  final issueId = notification['issueId'];
  final status = notification['status'] ?? '';

  Color statusColor = Colors.grey;
  String statusText = '';
  if (type == 'donation' || type == 'donation_request') {
  statusColor = status == 'approved'
  ? Colors.green
      : status == 'rejected'
  ? Colors.red
      : status == 'completed'
  ? Colors.blue
      : Colors.orange;
  statusText = status == 'approved'
  ? 'Approved'
      : status == 'rejected'
  ? 'Rejected'
      : status == 'completed'
  ? 'Completed'
      : 'Pending';
  } else if (type == 'issue_report' || type == 'issue_status_change') {
  statusColor = status == 'resolved'
  ? Colors.green
      : status == 'in_progress'
  ? Colors.blue
      : Colors.orange;
  statusText = status == 'resolved'
  ? 'Resolved'
      : status == 'in_progress'
  ? 'In Progress'
      : 'Open';
  }

  return Card(
  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  color: read ? Colors.white : Colors.blue[50],
  child: ListTile(
  leading: _getIconForType(type, read),
  title: Row(
  children: [
  Expanded(
  child: Text(
  title,
  style: const TextStyle(fontWeight: FontWeight.bold),
  ),
  ),
  if (status.isNotEmpty)
  Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
  color: statusColor,
  borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
  statusText,
  style: const TextStyle(color: Colors.white, fontSize: 12),
  ),
  ),
  ],
  ),
  subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text(message),
  Text(
  timestamp != null
  ? DateFormat('MMM d, h:mm a').format(timestamp)
      : 'Unknown',
  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
  ),
  ],
  ),
  onTap: () {
  if (!read) {
  _markAsRead(notificationId);
  }
  _navigateToDetails(type, donationId, issueId);
  },
  ),
  );
  },
  );
  },
  ),
  ),
  ],
  )
      : const Center(
  child: Text(
  'Notifications are disabled.',
  style: TextStyle(fontSize: 16, color: Colors.grey),
  ),
  ),
  );
  }
}