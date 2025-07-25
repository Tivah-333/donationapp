import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DonationDetailsPage extends StatefulWidget {
  final String donationId;

  const DonationDetailsPage({super.key, required this.donationId});

  @override
  State<DonationDetailsPage> createState() => _DonationDetailsPageState();
}

class _DonationDetailsPageState extends State<DonationDetailsPage> {
  late Future<List<QueryDocumentSnapshot>> _itemsFuture;
  final Map<String, String> _decisions = {};
  final Map<String, String?> _deliveryStatuses = {};
  final Set<String> _finalizedItems = {};

  @override
  void initState() {
    super.initState();
    _itemsFuture = _fetchDonationItems();
  }

  Future<List<QueryDocumentSnapshot>> _fetchDonationItems() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('donations')
        .doc(widget.donationId)
        .collection('items')
        .get();
    return snapshot.docs;
  }

  void _updateItemDecision(String itemId, String decision) {
    setState(() {
      _decisions[itemId] = decision;
    });
  }

  void _updateDeliveryStatus(String itemId, String? status) {
    setState(() {
      _deliveryStatuses[itemId] = status;
    });
  }

  Future<void> _finalizeDecision(String itemId) async {
    final decision = _decisions[itemId];
    final deliveryStatus = _deliveryStatuses[itemId];

    if (deliveryStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery status.')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('donations')
        .doc(widget.donationId)
        .collection('items')
        .doc(itemId)
        .update({
      'status': decision,
      'deliveryConfirmation': deliveryStatus,
    });

    setState(() {
      _finalizedItems.add(itemId);
    });

    final items = await _fetchDonationItems();
    final allFinalized = _finalizedItems.length == items.length;

    if (allFinalized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All items processed successfully.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No donation items found.'));
          }

          final items = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final itemId = item.id;
              final data = item.data() as Map<String, dynamic>;

              final category = data['category'] ?? 'N/A';
              final title = data['title'] ?? 'N/A';
              final description = data['description'] ?? 'N/A';
              final quantity = data['quantity']?.toString() ?? 'N/A';
              final deliveryOption = (data['deliveryOption'] ?? 'drop-off').toLowerCase();
              final status = data['status'] ?? 'pending';

              final decision = _decisions[itemId];
              final deliveryStatus = _deliveryStatuses[itemId];
              final finalized = _finalizedItems.contains(itemId) || status != 'pending';

              // Determine delivery status options dynamically
              final deliveryStatusOptions = deliveryOption == 'pickup'
                  ? ['Delivered', 'Not Delivered']
                  : ['Received', 'Not Received'];

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Item ${index + 1}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildDetail('Category', category),
                      _buildDetail('Title', title),
                      _buildDetail('Description', description),
                      _buildDetail('Quantity', quantity),
                      _buildDetail('Delivery Option', deliveryOption),
                      _buildDetail('Status', status),

                      // Here is the added delivery confirmation detail line:
                      _buildDetail('Delivery Confirmation', data['deliveryConfirmation'] ?? 'Not yet confirmed'),

                      const SizedBox(height: 16),

                      // Approve/Reject Buttons
                      if (!finalized && decision == null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () => _updateItemDecision(itemId, 'approved'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                minimumSize: const Size(120, 50),
                              ),
                              child: const Text('Approve', style: TextStyle(fontSize: 16)),
                            ),
                            ElevatedButton(
                              onPressed: () => _updateItemDecision(itemId, 'rejected'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                minimumSize: const Size(120, 50),
                              ),
                              child: const Text('Reject', style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),

                      // Delivery Status + Submit
                      if (!finalized && decision != null) ...[
                        const SizedBox(height: 16),
                        const Text('Delivery Status:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          value: deliveryStatus,
                          hint: const Text('Select delivery status'),
                          items: deliveryStatusOptions.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) => _updateDeliveryStatus(itemId, value),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _finalizeDecision(itemId),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('Submit Decision', style: TextStyle(fontSize: 16)),
                        ),
                      ],

                      // Finalized message
                      if (finalized)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Decision submitted',
                            style: TextStyle(
                                color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        )
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

  Widget _buildDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
