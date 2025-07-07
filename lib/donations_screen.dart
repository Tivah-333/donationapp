import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DonationsScreen extends StatefulWidget {
  const DonationsScreen({Key? key}) : super(key: key);

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  final TextEditingController _donationController = TextEditingController();

  final List<String> categories = [
    'Clothes',
    'Studying Materials',
    'Food Supplies',
    'Money or Cash',
    'Physical Items',
  ];

  Future<void> _addDonation() async {
    final input = _donationController.text.trim().toLowerCase();
    if (input.isEmpty) return;

    String category = 'Physical Items';

    if (_matchesAny(input, ['trouser', 'shirt', 't-shirt', 'dress', 'cloth', 'skirt', 'shoes'])) {
      category = 'Clothes';
    } else if (_matchesAny(input, ['book', 'pen', 'pencil', 'notebook'])) {
      category = 'Studying Materials';
    } else if (_matchesAny(input, ['rice', 'beans', 'food', 'maize', 'flour', 'sugar'])) {
      category = 'Food Supplies';
    } else if (_matchesAny(input, ['cash', 'money', 'donation', 'funds'])) {
      category = 'Money or Cash';
    }

    await FirebaseFirestore.instance.collection('donations').add({
      'item': _donationController.text.trim(),
      'category': category,
      'status': 'available',
      'timestamp': FieldValue.serverTimestamp(),
    });

    _donationController.clear();

    if (!mounted) return; // <-- Check if widget is still mounted

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added under "$category"')),
    );
  }

  bool _matchesAny(String input, List<String> keywords) {
    return keywords.any((word) => input.contains(word));
  }

  @override
  void dispose() {
    _donationController.dispose();
    super.dispose();
  }

  void _editDonation(DocumentSnapshot doc) async {
    final TextEditingController editController = TextEditingController(text: doc['item']);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Donation'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, editController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await doc.reference.update({'item': result});
      if (!mounted) return;  // <-- Check if widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation updated')),
      );
    }
  }

  void _deleteDonation(DocumentSnapshot doc) async {
    await doc.reference.delete();
    if (!mounted) return;  // <-- Check if widget is still mounted
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Donation deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Donations'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _donationController,
                    decoration: const InputDecoration(
                      labelText: 'Enter donation item',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addDonation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading donations'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                Map<String, List<QueryDocumentSnapshot>> grouped = {};
                for (var category in categories) {
                  grouped[category] = [];
                }
                for (var doc in docs) {
                  final category = doc['category'] ?? 'Physical Items';
                  grouped[category]?.add(doc);
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: categories.map((category) {
                    final items = grouped[category]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (items.isEmpty)
                          const Text(
                            '(No items)',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ...items.map(
                              (doc) => Card(
                            child: ListTile(
                              title: Text(doc['item']),
                              subtitle: Text('Status: ${doc['status']}'),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _editDonation(doc),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteDonation(doc),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
