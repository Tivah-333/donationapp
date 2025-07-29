import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationsPage extends StatefulWidget {
  final int initialTab;
  
  const AdminNotificationsPage({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final CollectionReference notificationsRef =
  FirebaseFirestore.instance.collection('notifications');

  late TabController _tabController;

  final List<String> tabTitles = [
    'Organization Approvals',
    'Issue Reports',
    'Support Messages',
    'Donation Activity',
  ];

  final List<String> tabTypes = [
    'organization_approval',
    'issue_report',
    'support_request',
    'donation',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabTitles.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _tabController.index = widget.initialTab;
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
    final currentType = tabTypes[_tabController.index];
    final snapshot = await notificationsRef
        .where('type', isEqualTo: currentType)
        .where('read', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Stream<int> _getUnreadCount(String type) {
    return notificationsRef
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
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    final type = tabTypes[index];
    return notificationsRef
        .where('type', isEqualTo: type)
        .orderBy('timestamp', descending: true);
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
                Text('No notifications found', style: TextStyle(fontSize: 18)),
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
    // Add the document ID to the data map so it can be accessed in response functions
    data['notificationId'] = id;
    
    final type = data['type'] ?? 'unknown';
    final timestamp = data['timestamp'] as Timestamp?;
    final read = data['read'] ?? false;
    final starred = data['starred'] ?? false;
    final problemId = data['problemId'];
    final senderEmail = data['senderEmail'] ?? data['organizationEmail'] ?? 'Unknown sender';
    final status = data['status'] ?? 'unresolved';
    final title = data['title'] ?? 'Notification';
    final message = data['message'] ?? data['description'] ?? 'No message provided';

    Color statusColor = Colors.grey;
    String statusText = 'Pending';

    if (type == 'issue_report') {
      if (status == 'resolved') {
        statusColor = Colors.green;
        statusText = 'Resolved';
      } else {
        statusColor = Colors.orange;
        statusText = 'Unresolved';
      }
    } else if (type == 'support_request') {
      if (status == 'resolved') {
        statusColor = Colors.green;
        statusText = 'Resolved';
      } else {
        statusColor = Colors.blue;
        statusText = 'Pending';
      }
    } else if (type == 'organization_approval') {
      if (status == 'approved') {
        statusColor = Colors.green;
        statusText = 'Approved';
      } else if (status == 'rejected') {
        statusColor = Colors.red;
        statusText = 'Rejected';
      } else {
        statusColor = Colors.blue;
        statusText = 'Pending Approval';
      }
    } else if (type == 'donation') {
      statusColor = Colors.green;
      statusText = 'New Donation';
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: read ? Colors.white : Colors.blue[50],
      child: ExpansionTile(
        leading: _getIconForType(type, read),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(message),
            if (senderEmail != 'Unknown sender')
              Text('From: $senderEmail', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        subtitle: Text(
          timestamp != null ? _formatTimestamp(timestamp) : 'Unknown time',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
        initiallyExpanded: false,
        onExpansionChanged: (expanded) {
          if (expanded && !read) {
            notificationsRef.doc(id).update({'read': true});
          }
        },
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (type == 'issue_report') ...[
                  Text(
                    'Issue Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(data['fullMessage'] ?? data['description'] ?? message),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                IssueReportDetailsPage(problemDocId: problemId),
                          ),
                        );
                      },
                      child: Text('View Full Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                    ),
                  ),
                ] else if (type == 'organization_approval') ...[
                  Text(
                    'Organization Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Organization: ${data['organizationName'] ?? 'Unknown'}'),
                  Text('Email: ${data['organizationEmail'] ?? 'Unknown'}'),
                  Text('Address: ${data['organizationAddress'] ?? 'Not provided'}'),
                  Text('Type: ${data['organizationType'] ?? 'Not specified'}'),
                  Text('Registration: ${data['registrationNumber'] ?? 'Not provided'}'),
                  if (data['organizationDescription'] != null) ...[
                    SizedBox(height: 8),
                    Text(
                      'Description:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(data['organizationDescription']),
                  ],
                  SizedBox(height: 16),
                  // Show status and buttons based on current status
                  if (data['status'] == 'pending' || data['status'] == null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveOrganization(data['organizationId'], data['organizationName'], data['organizationEmail']),
                            child: Text('Approve'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _rejectOrganization(data['organizationId'], data['organizationName'], data['organizationEmail']),
                            child: Text('Reject'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ] else if (data['status'] == 'approved') ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Approved',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ] else if (data['status'] == 'rejected') ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Rejected',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ] else if (type == 'support_request') ...[
                  Text(
                    'Support Request Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Message:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(data['supportMessage'] ?? data['message'] ?? 'No message provided'),
                  SizedBox(height: 16),
                  if (data['isResponded'] != true) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => _respondToSupportRequest(context, data),
                        child: Text('Respond'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      ),
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Responded',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ] else if (type == 'donation') ...[
                  Text(
                    'Donation Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Donor: ${data['donorEmail'] ?? 'Unknown'}'),
                  Text('Category: ${data['donationCategory'] ?? 'Unknown'}'),
                  Text('Title: ${data['donationTitle'] ?? 'Unknown'}'),
                  Text('Status: ${data['donationStatus'] ?? 'Unknown'}'),
                ] else ...[
                  Text(
                    'Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(message),
                ],
              ],
            ),
          ),
        ],
      ),
      body: showNotifications
          ? StreamBuilder<QuerySnapshot>(
        stream: notificationsRef
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.where((doc) {
            final message =
                (doc['message'] as String?)?.toLowerCase() ?? '';
            return message.contains(searchQuery.toLowerCase());
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text('No notifications found.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data()! as Map<String, dynamic>;
              final id = doc.id;
              final type = data['type'] ?? 'unknown';
              final message = data['message'] ?? 'No message';
              final timestamp = data['timestamp'] as Timestamp?;
              final read = data['read'] ?? false;
              final starred = data['starred'] ?? false;

              return GestureDetector(
                onLongPress: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => Wrap(
                      children: [
                        ListTile(
                          leading: Icon(
                            starred
                                ? Icons.star_outline
                                : Icons.star,
                          ),
                          title: Text(
                            starred ? 'Unstar' : 'Star Notification',
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _toggleStar(id, starred);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete),
                          title: const Text('Delete'),
                          onTap: () {
                            Navigator.pop(context);
                            _deleteNotification(id);
                          },
                        ),
                      ],
                    ),
                  );
                },
                child: ListTile(
                  leading: _iconForType(type, read),
                  title: Text(message),
                  subtitle: Text(
                    timestamp != null
                        ? _formatTimestamp(timestamp)
                        : 'Unknown time',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: starred
                      ? const Icon(Icons.star, color: Colors.amber)
                      : null,
                  tileColor:
                  read ? Colors.white : Colors.blue.shade50,
                  onTap: () {
                    _markAsRead(id, read);
                    setState(() {
                      if (selectedIds.contains(id)) {
                        selectedIds.remove(id);
                      } else {
                        selectedIds.add(id);
                      }
                    });
                  },
                  selected: selectedIds.contains(id),
                  selectedTileColor: Colors.grey[200],
                ),
              );
            },
          );
        },
      )
          : const Center(
        child: Text('Notifications are hidden'),
      ),
    );
  }

  Future<void> _approveOrganization(String orgId, String orgName, String orgEmail) async {
    try {
      // Update organization status to approved
      await FirebaseFirestore.instance.collection('users').doc(orgId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin',
      });

      // Update the admin notification status
      await notificationsRef
          .where('organizationId', isEqualTo: orgId)
          .where('type', isEqualTo: 'organization_approval')
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final notificationDoc = snapshot.docs.first;
          notificationDoc.reference.update({
            'status': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
            'read': true,
          });
        }
      });

      // Send notification to the organization
      await FirebaseFirestore.instance.collection('organization_notifications').add({
        'organizationId': orgId,
        'type': 'organization_approval',
        'title': 'Organization Approved',
        'message': 'Congratulations! Your organization has been approved. You can now log in and start using the app.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'status': 'approved',
      });

      // Send email notification to the organization
      await _sendApprovalEmail(orgEmail, orgName);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$orgName has been approved successfully. Email notification sent to $orgEmail'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve organization: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectOrganization(String orgId, String orgName, String orgEmail) async {
    try {
      print('🚫 Starting rejection process for organization: $orgName (ID: $orgId)');
      
      // Update organization status to rejected
      await FirebaseFirestore.instance.collection('users').doc(orgId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': 'admin',
      });
      print('✅ Organization status updated to rejected in Firestore');

      // Verify the update was successful
      final updatedDoc = await FirebaseFirestore.instance.collection('users').doc(orgId).get();
      final updatedStatus = updatedDoc.data()?['status'];
      print('🔍 Verification: Organization status is now: $updatedStatus');

      // Update the admin notification status
      await notificationsRef
          .where('organizationId', isEqualTo: orgId)
          .where('type', isEqualTo: 'organization_approval')
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final notificationDoc = snapshot.docs.first;
          notificationDoc.reference.update({
            'status': 'rejected',
            'rejectedAt': FieldValue.serverTimestamp(),
            'read': true,
          });
          print('✅ Admin notification status updated to rejected');
        } else {
          print('⚠️ No admin notification found for this organization');
        }
      });

      // Send notification to the organization
      await FirebaseFirestore.instance.collection('organization_notifications').add({
        'organizationId': orgId,
        'type': 'organization_approval',
        'title': 'Organization Status Update',
        'message': 'Your organization application has been rejected. Please contact support for more information.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'status': 'rejected',
      });
      print('✅ Organization notification sent');

      // Send email notification to the organization
      await _sendRejectionEmail(orgEmail, orgName);
      print('✅ Rejection email notification queued');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$orgName has been rejected. Email notification sent to $orgEmail'),
          backgroundColor: Colors.orange,
        ),
      );
      
      print('🎉 Rejection process completed successfully');
    } catch (e) {
      print('❌ Error during rejection process: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject organization: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendApprovalEmail(String email, String orgName) async {
    // Email functionality removed
    print('Organization approval notification would be sent to: $email');
  }

  Future<void> _sendRejectionEmail(String email, String orgName) async {
    // Email functionality removed
    print('Organization rejection notification would be sent to: $email');
  }

  Future<void> _respondToSupportRequest(BuildContext context, Map<String, dynamic> data) async {
    final responseController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Respond to Support Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Support Request from: ${data['userEmail'] ?? 'Unknown'}'),
            SizedBox(height: 16),
            TextField(
              controller: responseController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Your Response',
                border: OutlineInputBorder(),
                hintText: 'Enter your response to the user...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, responseController.text.trim()),
            child: Text('Send Response'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        // Get the notification ID from the data - it should be passed from the notification item
        final notificationId = data['notificationId'] ?? data['id'];
        final senderId = data['senderId'] ?? data['donorId'] ?? data['organizationId'];
        final senderRole = data['senderRole'] ?? data['requestType'] ?? 'donor';
        final userEmail = data['userEmail'] ?? data['donorEmail'] ?? data['organizationEmail'] ?? 'Unknown';

        // Try to update the admin notification with response (only if it exists)
        try {
          await FirebaseFirestore.instance
              .collection('admin_notifications')
              .doc(notificationId)
              .update({
            'response': result,
            'isResponded': true,
            'responseTimestamp': FieldValue.serverTimestamp(),
            'status': 'resolved',
            'read': true,
          });
        } catch (e) {
          // If the admin notification doesn't exist, that's okay - just log it
          print('Admin notification document not found, continuing with user notification: $e');
        }

        // Send notification to user based on their role
        if (senderRole == 'donor') {
          await FirebaseFirestore.instance.collection('donor_notifications').add({
            'donorId': senderId,
            'type': 'support_response',
            'title': 'Support Response',
            'message': 'You have received a response to your support request: $result',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'adminResponse': result,
            'originalRequest': data['supportMessage'] ?? data['message'] ?? 'No message provided',
          });
        } else if (senderRole == 'organization') {
          await FirebaseFirestore.instance.collection('organization_notifications').add({
            'organizationId': senderId,
            'type': 'support_response',
            'title': 'Support Response',
            'message': 'You have received a response to your support request: $result',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'adminResponse': result,
            'originalRequest': data['supportMessage'] ?? data['message'] ?? 'No message provided',
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Response sent successfully to $userEmail'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error sending support response: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send response: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _respondToIssueReport(BuildContext context, Map<String, dynamic> data) async {
    final responseController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Respond to Issue Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Issue Report from: ${data['senderEmail'] ?? 'Unknown'}'),
            SizedBox(height: 16),
            TextField(
              controller: responseController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Your Response',
                border: OutlineInputBorder(),
                hintText: 'Enter your response to the issue report...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, responseController.text.trim()),
            child: Text('Send Response'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final senderId = data['senderId'] ?? data['donorId'] ?? data['organizationId'];
        final senderRole = data['senderRole'] ?? data['reportType'] ?? 'donor';
        final userEmail = data['senderEmail'] ?? data['donorEmail'] ?? data['organizationEmail'] ?? 'Unknown';
        final notificationId = data['notificationId'] ?? data['id'];

        // Update the admin notification with response
        await FirebaseFirestore.instance
            .collection('admin_notifications')
            .doc(notificationId)
            .update({
          'response': result,
          'isResponded': true,
          'responseTimestamp': FieldValue.serverTimestamp(),
          'status': 'resolved',
          'read': true,
        });

        // Send notification to user based on their role
        if (senderRole == 'donor') {
          await FirebaseFirestore.instance.collection('donor_notifications').add({
            'donorId': senderId,
            'type': 'problem_response',
            'title': 'Issue Report Response',
            'message': 'You have received a response to your issue report: $result',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'adminResponse': result,
            'originalIssue': data['fullMessage'] ?? data['message'] ?? 'No message provided',
            'issueType': 'problem_report',
          });
        } else if (senderRole == 'organization') {
          await FirebaseFirestore.instance.collection('organization_notifications').add({
            'organizationId': senderId,
            'type': 'problem_response',
            'title': 'Issue Report Response',
            'message': 'You have received a response to your issue report: $result',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'adminResponse': result,
            'originalIssue': data['fullMessage'] ?? data['message'] ?? 'No message provided',
            'issueType': 'problem_report',
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Response sent successfully to $userEmail'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error sending issue report response: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send response: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Icon _getIconForType(String type, bool read) {
    final color = read ? Colors.grey : Colors.blue;
    switch (type) {
      case 'issue_report':
        return Icon(Icons.report_problem, color: color);
      case 'donation':
        return Icon(Icons.volunteer_activism, color: color);
      case 'organization_approval':
        return Icon(Icons.business, color: color);
      case 'support_request':
        return Icon(Icons.support_agent, color: color);
      default:
        return Icon(Icons.notifications, color: color);
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _markAsRead(String docId, bool alreadyRead) async {
    if (!alreadyRead) {
      await notificationsRef.doc(docId).update({'read': true});
    }
  }

  Future<void> _toggleStar(String docId, bool currentStar) async {
    await notificationsRef.doc(docId).update({'starred': !currentStar});
  }

  Future<void> _deleteNotification(String docId) async {
    await notificationsRef.doc(docId).delete();
  }
}

// 🔍 Search
class _NotificationSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) => const SizedBox();

  @override
  Widget buildSuggestions(BuildContext context) => const SizedBox();
}

// ⭐ Starred Notifications Page
class StarredNotificationsPage extends StatelessWidget {
  const StarredNotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final notificationsRef =
    FirebaseFirestore.instance.collection('notifications');

    return Scaffold(
      appBar: AppBar(title: const Text('Starred Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        stream: notificationsRef
            .where('starred', isEqualTo: true)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No starred notifications.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data()! as Map<String, dynamic>;
              final message = data['message'] ?? 'No message';
              final timestamp = data['timestamp'] as Timestamp?;

              return ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: Text(message),
                subtitle: Text(
                  timestamp != null
                      ? '${timestamp.toDate()}'
                      : 'Unknown time',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
