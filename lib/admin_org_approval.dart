import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOrgApprovalDashboard extends StatefulWidget {
  const AdminOrgApprovalDashboard({super.key});

  @override
  State<AdminOrgApprovalDashboard> createState() => _AdminOrgApprovalDashboardState();
}

class _AdminOrgApprovalDashboardState extends State<AdminOrgApprovalDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int pendingCount = 0;
  int approvedCount = 0;
  int rejectedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchCounts();
  }

  Future<void> fetchCounts() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Organization')
        .get();

    int pending = 0, approved = 0, rejected = 0;

    for (var doc in querySnapshot.docs) {
      final status = doc['status'] ?? 'pending';
      if (status == 'pending') pending++;
      else if (status == 'approved') approved++;
      else if (status == 'rejected') rejected++;
    }

    setState(() {
      pendingCount = pending;
      approvedCount = approved;
      rejectedCount = rejected;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget buildOrgList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Organization')
          .where('status', isEqualTo: status)
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
          return Center(child: Text('No $status organizations.'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final email = data['email'] ?? 'No email';
            final createdAt = data['createdAt'] != null
                ? (data['createdAt'] as Timestamp).toDate()
                : null;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(email),
                subtitle: createdAt != null
                    ? Text('Registered: ${createdAt.toLocal().toString().split(' ')[0]}')
                    : null,
                trailing: status == 'pending'
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      tooltip: 'Approve',
                      onPressed: () => updateStatus(doc.id, 'approved'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: 'Reject',
                      onPressed: () => updateStatus(doc.id, 'rejected'),
                    ),
                  ],
                )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> updateStatus(String docId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'status': newStatus,
      });
      fetchCounts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Organization $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Organization Approval'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Pending ($pendingCount)'),
            Tab(text: 'Approved ($approvedCount)'),
            Tab(text: 'Rejected ($rejectedCount)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildOrgList('pending'),
          buildOrgList('approved'),
          buildOrgList('rejected'),
        ],
      ),
    );
  }
}
