import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'IssueReportDetailsPage.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({Key? key}) : super(key: key);

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage>
    with SingleTickerProviderStateMixin {
  final CollectionReference notificationsRef =
  FirebaseFirestore.instance.collection('admin_notifications');

  late TabController _tabController;

  final List<String> tabTitles = [
    'Approvals',
    'Issue Reports',
    'Support Messages',
    'Donation Activity',
    'Admin Activity Log',
  ];

  final List<String> tabTypes = [
    'approval',
    'issue_report',
    'support_message',
    'donation',
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
    final type = data['type'] ?? 'unknown';
    final timestamp = data['timestamp'] as Timestamp?;
    final read = data['read'] ?? false;
    final starred = data['starred'] ?? false;
    final problemId = data['problemId'];
    final senderEmail = data['senderEmail'] ?? 'Unknown sender';
    final status = data['status'] ?? 'unresolved';

    // Use shortMessage and fullMessage for both organization and donor uniformly
    final shortMessage = (data['shortMessage'] != null &&
        data['shortMessage'].toString().trim().isNotEmpty)
        ? data['shortMessage']
        : 'Problem reported by $senderEmail';

    final fullMessage = (data['fullMessage'] != null &&
        data['fullMessage'].toString().trim().isNotEmpty)
        ? data['fullMessage']
        : (data['message'] != null && data['message'].toString().trim().isNotEmpty)
        ? data['message']
        : 'Issue details were not provided by $senderEmail.';

    final showDetails = data['showDetails'] ?? false;

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
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: read ? Colors.white : Colors.blue[50],
      child: ExpansionTile(
        leading: _getIconForType(type, read),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(senderEmail, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(shortMessage),
          ],
        ),
        subtitle: Text(
          timestamp != null ? _formatTimestamp(timestamp) : 'Unknown time',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'issue_report')
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
        initiallyExpanded: showDetails,
        onExpansionChanged: (expanded) {
          if (expanded && !read) {
            notificationsRef.doc(id).update({'read': true});
          }
          notificationsRef.doc(id).update({'showDetails': expanded});
        },
        children: [
          if (type == 'issue_report')
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Issue Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(fullMessage),
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
                ],
              ),
            ),
        ],
      ),
    );
  }

  Icon _getIconForType(String type, bool read) {
    final color = read ? Colors.grey : Colors.blue;
    switch (type) {
      case 'issue_report':
        return Icon(Icons.report_problem, color: color);
      case 'donation':
        return Icon(Icons.volunteer_activism, color: color);
      default:
        return Icon(Icons.notifications, color: color);
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('MMM d, y • h:mm a').format(date);
  }
}

