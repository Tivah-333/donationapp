import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageDonations extends StatelessWidget {
  const ManageDonations({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Donations'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] ?? 'No title';
              final category = data['category'] ?? 'Unknown';
              final status = data['status'] ?? 'N/A';
              final lastEdited = data['lastEditedAt'] != null
                  ? DateFormat('MMM d, h:mm a').format((data['lastEditedAt'] as Timestamp).toDate())
                  : null;
              final lastEditedBy = data['lastEditedBy'];

              return Card(
                child: ListTile(
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category: $category'),
                      Text('Status: $status'),
                      if (lastEditedBy != null && lastEdited != null)
                        Text('Last edited by $lastEditedBy on $lastEdited',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editDonation(context, doc.id, title),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteDonation(context, doc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _editDonation(BuildContext context, String docId, String currentValue) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Donation Title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New title'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await FirebaseFirestore.instance.collection('donations').doc(docId).update({
                  'title': newName,
                  'lastEditedBy': 'admin',
                  'lastEditedAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  void _deleteDonation(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Donation'),
        content: const Text('Are you sure you want to delete this donation?'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
          ElevatedButton(child: const Text('Delete'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('donations').doc(docId).delete();
    }
  }
}
