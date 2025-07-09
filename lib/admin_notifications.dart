import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({Key? key}) : super(key: key);

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final CollectionReference notificationsRef =
  FirebaseFirestore.instance.collection('notifications');

  bool showNotifications = true;
  String searchQuery = '';
  Set<String> selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search notifications',
            onPressed: () async {
              final query = await showSearch<String>(
                context: context,
                delegate: _NotificationSearchDelegate(),
              );
              if (query != null) {
                setState(() => searchQuery = query);
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'mark_all') {
                final snapshot = await notificationsRef.get();
                for (var doc in snapshot.docs) {
                  await doc.reference.update({'read': true});
                }
              } else if (value == 'starred') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StarredNotificationsPage(),
                  ),
                );
              } else if (value == 'delete_selected') {
                for (var id in selectedIds) {
                  await notificationsRef.doc(id).delete();
                }
                setState(() => selectedIds.clear());
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all',
                child: Text('Mark all as read'),
              ),
              const PopupMenuItem(
                value: 'starred',
                child: Text('Starred'),
              ),
              const PopupMenuItem(
                value: 'delete_selected',
                child: Text('Delete selected'),
              ),
            ],
          ),
          Tooltip(
            message: showNotifications ? 'Hide notifications' : 'Show notifications',
            child: Switch(
              value: showNotifications,
              onChanged: (value) {
                setState(() => showNotifications = value);
              },
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

  Widget _iconForType(String type, bool read) {
    final color = read ? Colors.grey : Colors.blue;
    switch (type) {
      case 'issue_report':
        return Icon(Icons.report_problem, color: color);
      case 'donation':
        return Icon(Icons.volunteer_activism, color: color);
      case 'org_registration':
        return Icon(Icons.apartment, color: color);
      case 'issue_status_change':
        return Icon(Icons.settings_backup_restore, color: color);
      case 'item_request':
        return Icon(Icons.inventory, color: color);
      case 'issue_comment':
        return Icon(Icons.comment, color: color);
      case 'org_suspended':
        return Icon(Icons.block, color: color);
      case 'message':
        return Icon(Icons.mail, color: color);
      case 'overdue_issue':
        return Icon(Icons.access_time, color: color);
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
