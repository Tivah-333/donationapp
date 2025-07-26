import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'IssueReportDetailsPage.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({Key? key}) : super(key: key);

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage>
    with SingleTickerProviderStateMixin {
  final String apiUrl = 'http://127.0.0.1:5001/donationapp-3c/us-central1/api';

  late TabController _tabController;

  final List<String> tabTitles = [
    'Approvals',
    'Issue Reports',
    'Support Messages',
    'Donation Activity',
    'Admin Activity Log',
  ];

  final List<String> tabTypes = [
    'user_registration',
    'issue_report',
    'support_request',
    'donation_request',
    'admin_activity',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabTitles.length, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _markCurrentTabAsRead();
    }
  }

  Future<void> _markCurrentTabAsRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();
      final currentType = tabTypes[_tabController.index];
      final response = await http.get(
        Uri.parse('$apiUrl/notifications?recipientId=${user.uid}&type=$currentType&read=false'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking notifications as read: $e')),
      );
    }
  }

  Stream<int> _getUnreadCount(String type) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: user.uid)
        .where('type', isEqualTo: type)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Widget _buildTabTitleWithBadge(String title, Stream<int> countStream) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Query _getQueryForTab(int index) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return FirebaseFirestore.instance.collection('notifications').where('recipientId', isEqualTo: '');
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: user.uid)
        .where('type', isEqualTo: tabTypes[index])
        .orderBy('timestamp', descending: true);
  }

  Future<void> _respondToNotification(String type, String docId, String recipientId) async {
    final responseController = TextEditingController();
    final statusOptions = type == 'support_request' || type == 'issue_report'
        ? ['open', 'in_progress', 'resolved']
        : type == 'donation_request'
        ? ['pending', 'approved', 'rejected', 'completed']
        : type == 'user_registration'
        ? ['pending', 'approved', 'rejected']
        : [];
    String? selectedStatus;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          type == 'support_request'
              ? 'Respond to Support Request'
              : type == 'issue_report'
              ? 'Respond to Issue Report'
              : type == 'donation_request'
              ? 'Respond to Donation Request'
              : 'Respond to Organization Registration',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type != 'user_registration')
              TextField(
                controller: responseController,
                decoration: const InputDecoration(labelText: 'Response'),
                maxLines: 3,
              ),
            if (statusOptions.isNotEmpty)
              DropdownButtonFormField<String>(
                hint: const Text('Select Status'),
                value: selectedStatus,
                items: statusOptions
                    .map((status) => DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                ))
                    .toList(),
                onChanged: (value) => selectedStatus = value,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'response': responseController.text.trim(),
              'status': selectedStatus,
            }),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not authenticated');
        final idToken = await user.getIdToken();
        final endpoint = type == 'support_request'
            ? '$apiUrl/support/$docId/respond'
            : type == 'issue_report'
            ? '$apiUrl/support/issues/$docId/respond'
            : type == 'donation_request'
            ? '$apiUrl/donations/$docId'
            : '$apiUrl/users/$recipientId';
        final response = await http.put(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(result),
        );
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Response sent')),
          );
        } else {
          throw Exception('Failed to send response: ${response.body}');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: List.generate(tabTitles.length, (index) {
            return Tab(
              child: _buildTabTitleWithBadge(
                tabTitles[index],
                _getUnreadCount(tabTypes[index]),
              ),
            );
          }),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(tabTitles.length, (index) {
          return _buildNotificationList(index);
        }),
      ),
    );
  }

  Widget _buildNotificationList(int tabIndex) {
    final query = _getQueryForTab(tabIndex);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('No ${tabTitles[tabIndex].toLowerCase()} found', style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildNotificationItem(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildNotificationItem(String id, Map<String, dynamic> data) {
    final type = data['type'] ?? 'unknown';
    final timestamp = data['timestamp'] as Timestamp?;
    final read = data['read'] ?? false;
    final starred = data['starred'] ?? false;
    final senderEmail = data['senderEmail'] ?? data['donorEmail'] ?? 'Unknown sender';
    final docId = data['issueId'] ?? data['donationId'] ?? data['recipientId'] ?? id;
    final message = data['message'] ?? 'No details provided';
    String status = '';
    if (type == 'issue_report') {
      status = data['status'] ?? 'open';
    } else if (type == 'donation_request') {
      status = data['status'] ?? 'pending';
    } else if (type == 'user_registration') {
      status = data['status'] ?? 'pending';
    }

    Color statusColor = Colors.grey;
    String statusText = '';
    if (type == 'issue_report') {
      statusColor = status == 'resolved' ? Colors.green : status == 'in_progress' ? Colors.blue : Colors.orange;
      statusText = status == 'resolved' ? 'Resolved' : status == 'in_progress' ? 'In Progress' : 'Open';
    } else if (type == 'donation_request') {
      statusColor = status == 'approved' ? Colors.green : status == 'rejected' ? Colors.red : status == 'completed' ? Colors.blue : Colors.orange;
      statusText = status == 'approved' ? 'Approved' : status == 'rejected' ? 'Rejected' : status == 'completed' ? 'Completed' : 'Pending';
    } else if (type == 'user_registration') {
      statusColor = status == 'approved' ? Colors.green : status == 'rejected' ? Colors.red : Colors.orange;
      statusText = status == 'approved' ? 'Approved' : status == 'rejected' ? 'Rejected' : 'Pending';
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: read ? Colors.white : Colors.blue[50],
      child: ListTile(
        leading: _getIconForType(type, read),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(senderEmail, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(message),
          ],
        ),
        subtitle: Text(
          timestamp != null ? _formatTimestamp(timestamp) : 'Unknown time',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            if (starred) Icon(Icons.star, color: Colors.amber),
          ],
        ),
        onTap: () {
          if (type == 'issue_report') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => IssueReportDetailsPage(problemDocId: data['issueId']),
              ),
            );
          } else {
            _respondToNotification(type, docId, data['recipientId'] ?? data['senderId']);
            if (!read) {
              FirebaseFirestore.instance.collection('notifications').doc(id).update({'read': true});
            }
          }
        },
      ),
    );
  }

  Icon _getIconForType(String type, bool read) {
    final color = read ? Colors.grey : Colors.blue;
    switch (type) {
      case 'issue_report':
        return Icon(Icons.report_problem, color: color);
      case 'donation_request':
        return Icon(Icons.volunteer_activism, color: color);
      case 'support_request':
        return Icon(Icons.support, color: color);
      case 'user_registration':
        return Icon(Icons.apartment, color: color);
      default:
        return Icon(Icons.notifications, color: color);
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('MMM d, y • h:mm a').format(date);
  }
}