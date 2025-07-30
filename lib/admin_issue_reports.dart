import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'services/notification_service.dart';

class AdminIssueReportsPage extends StatefulWidget {
  const AdminIssueReportsPage({Key? key}) : super(key: key);

  @override
  State<AdminIssueReportsPage> createState() => _AdminIssueReportsPageState();
}

class _AdminIssueReportsPageState extends State<AdminIssueReportsPage>
    with SingleTickerProviderStateMixin {
  String filterStatus = 'All';
  final List<String> statusOptions = ['All', 'Pending', 'In Progress', 'Resolved'];
  DateTime? startDate;
  DateTime? endDate;
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
  }

  Future<void> pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Reports'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.black, // Ensure text and icons are dark
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Archived'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: filterStatus,
                  items: statusOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      filterStatus = value!;
                    });
                  },
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: pickDateRange,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Filter by Date'),
                ),
                if (startDate != null && endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      '${DateFormat('MM/dd').format(startDate!)} - ${DateFormat('MM/dd').format(endDate!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                _buildIssuesList(isArchived: false),
                _buildIssuesList(isArchived: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesList({required bool isArchived}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('issues')
          .where('archived', isEqualTo: isArchived)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Failed to load issues. Please check your connection.'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allIssues = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString();
          final ts = data['timestamp'] as Timestamp?;
          final date = ts?.toDate();

          if (filterStatus != 'All' && status != filterStatus) return false;
          if (startDate != null && endDate != null && date != null) {
            return date.isAfter(startDate!.subtract(const Duration(days: 1))) &&
                date.isBefore(endDate!.add(const Duration(days: 1)));
          }
          return true;
        }).toList();

        if (allIssues.isEmpty) {
          return const Center(child: Text('No issues found.'));
        }

        return ListView.builder(
          itemCount: allIssues.length,
          itemBuilder: (context, index) {
            final doc = allIssues[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

            return Card(
              child: ListTile(
                title: Text(data['description'] ?? 'No Description'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${data['status'] ?? 'Unknown'}'),
                    if (timestamp != null)
                      Text('Reported on: ${DateFormat('yMMMd').format(timestamp)}'),
                  ],
                ),
                onTap: () => _showIssueDetails(doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  void _showIssueDetails(String issueId, Map<String, dynamic> data) {
    final TextEditingController commentController = TextEditingController();
    String currentStatus = data['status'] ?? 'Pending';
    bool isArchived = data['archived'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Description:', style: Theme.of(context).textTheme.titleMedium),
                Text(data['description'] ?? ''),
                const SizedBox(height: 10),
                Text('Status:', style: Theme.of(context).textTheme.titleMedium),
                DropdownButton<String>(
                  value: currentStatus,
                  items: ['Pending', 'In Progress', 'Resolved']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      try {
                        await FirebaseFirestore.instance
                            .collection('issues')
                            .doc(issueId)
                            .update({'status': value});
                        setState(() {
                          currentStatus = value;
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to update status. Please try again.')),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(isArchived ? Icons.unarchive : Icons.archive),
                      label: Text(isArchived ? 'Unarchive' : 'Archive'),
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('issues')
                              .doc(issueId)
                              .update({'archived': !isArchived});
                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to update archive status. Please try again.')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const Divider(),
                Text('Add Comment:', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: const InputDecoration(hintText: 'Write a comment...'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final text = commentController.text.trim();
                        if (text.isNotEmpty) {
                          try {
                            // Update the issue with the comment
                            await FirebaseFirestore.instance
                                .collection('issues')
                                .doc(issueId)
                                .update({
                              'comments': FieldValue.arrayUnion([
                                {
                                  'text': text,
                                  'timestamp': FieldValue.serverTimestamp(),
                                }
                              ])
                            });

                            // Send notification to the user who reported the issue
                            final userId = data['userId'] as String?;
                            final userType = data['userType'] as String?;
                            
                            if (userId != null && userType != null) {
                              if (userType == 'donor') {
                                await NotificationService.sendProblemResponseNotification(
                                  donorId: userId,
                                  response: text,
                                  adminName: 'Admin',
                                  issueType: 'problem_report',
                                );
                              } else if (userType == 'organization') {
                                await NotificationService.sendOrgProblemResponseNotification(
                                  organizationId: userId,
                                  response: text,
                                  adminName: 'Admin',
                                  issueType: 'problem_report',
                                );
                              }
                            }

                            commentController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Comment added and notification sent.')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to add comment. Please try again.')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

