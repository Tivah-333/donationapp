import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'services/notification_service.dart';

class AdminSupportRequestsPage extends StatefulWidget {
  const AdminSupportRequestsPage({Key? key}) : super(key: key);

  @override
  State<AdminSupportRequestsPage> createState() => _AdminSupportRequestsPageState();
}

class _AdminSupportRequestsPageState extends State<AdminSupportRequestsPage>
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
        title: const Text('Support Requests'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.black,
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
                _buildSupportRequestsList(isArchived: false),
                _buildSupportRequestsList(isArchived: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportRequestsList({required bool isArchived}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_requests')
          .where('archived', isEqualTo: isArchived)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Failed to load support requests. Please check your connection.'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRequests = snapshot.data!.docs.where((doc) {
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

        if (allRequests.isEmpty) {
          return const Center(child: Text('No support requests found.'));
        }

        return ListView.builder(
          itemCount: allRequests.length,
          itemBuilder: (context, index) {
            final doc = allRequests[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            final userType = data['userType'] as String? ?? 'Unknown';

            return Card(
              child: ListTile(
                title: Text(data['message'] ?? 'No Message'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From: ${data['userEmail'] ?? 'Unknown'} ($userType)'),
                    Text('Status: ${data['status'] ?? 'Unknown'}'),
                    if (timestamp != null)
                      Text('Requested on: ${DateFormat('yMMMd').format(timestamp)}'),
                  ],
                ),
                onTap: () => _showSupportRequestDetails(doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  void _showSupportRequestDetails(String requestId, Map<String, dynamic> data) {
    final TextEditingController responseController = TextEditingController();
    String currentStatus = data['status'] ?? 'Pending';
    bool isArchived = data['archived'] ?? false;
    final userType = data['userType'] as String? ?? 'Unknown';
    final userId = data['userId'] as String?;

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
                Text('Message:', style: Theme.of(context).textTheme.titleMedium),
                Text(data['message'] ?? ''),
                const SizedBox(height: 10),
                Text('From: ${data['userEmail'] ?? 'Unknown'} ($userType)'),
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
                            .collection('support_requests')
                            .doc(requestId)
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
                              .collection('support_requests')
                              .doc(requestId)
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
                Text('Add Response:', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: responseController,
                        decoration: const InputDecoration(hintText: 'Write a response...'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final text = responseController.text.trim();
                        if (text.isNotEmpty && userId != null) {
                          try {
                            // Update the support request with the response
                            await FirebaseFirestore.instance
                                .collection('support_requests')
                                .doc(requestId)
                                .update({
                              'response': text,
                              'respondedAt': FieldValue.serverTimestamp(),
                              'status': 'Resolved',
                            });

                            // Send notification to the user
                            if (userType == 'donor') {
                              await NotificationService.sendProblemResponseNotification(
                                donorId: userId,
                                response: text,
                                adminName: 'Admin',
                                issueType: 'support_request',
                              );
                            } else if (userType == 'organization') {
                              await NotificationService.sendOrgSupportResponseNotification(
                                organizationId: userId,
                                response: text,
                                adminName: 'Admin',
                              );
                            }

                            responseController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Response sent and notification delivered.')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to send response. Please try again.')),
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