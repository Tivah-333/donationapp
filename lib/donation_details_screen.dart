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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .doc(widget.donationId)
            .snapshots(),
        builder: (context, donationSnapshot) {
          if (donationSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!donationSnapshot.hasData || !donationSnapshot.data!.exists) {
            return const Center(child: Text('Donation not found.'));
          }

          final donationData = donationSnapshot.data!.data() as Map<String, dynamic>;
          
          // Show assigned quantity and category if available
          final assignedQuantity = donationData['assignedQuantity'] as int?;
          final assignedCategory = donationData['assignedCategory'] as String?;
          final originalCategorySummary = donationData['originalCategorySummary'] as Map<String, dynamic>?;
          final categorySummary = donationData['categorySummary'] as Map<String, dynamic>?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Donation Overview Card
                Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assigned Donation Details',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        
                        if (assignedQuantity != null && assignedCategory != null) ...[
                          _buildDetail('Assigned Category', assignedCategory),
                          _buildDetail('Assigned Quantity', assignedQuantity.toString()),
                          _buildDetail('Donor Email', donationData['donorEmail'] ?? 'Unknown'),
                          _buildDetail('Assigned At', _formatTimestamp(donationData['assignedAt'])),
                          _buildDetail('Delivery Method', donationData['deliveryOption'] ?? 'Unknown'),
                          if (donationData['pickupStation'] != null)
                            _buildDetail('Pickup Station', donationData['pickupStation']),
                          _buildDetail('Location', donationData['location'] ?? 'Unknown'),
                        ] else ...[
                          // Show original donation details if not assigned
                          _buildDetail('Categories', (donationData['categories'] as List<dynamic>?)?.join(', ') ?? 'Unknown'),
                          _buildDetail('Total Quantity', (donationData['totalQuantity'] ?? 0).toString()),
                          _buildDetail('Donor Email', donationData['donorEmail'] ?? 'Unknown'),
                          _buildDetail('Delivery Method', donationData['deliveryOption'] ?? 'Unknown'),
                          if (donationData['pickupStation'] != null)
                            _buildDetail('Pickup Station', donationData['pickupStation']),
                          _buildDetail('Location', donationData['location'] ?? 'Unknown'),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      return '${timestamp.toDate().toLocal()}';
    }
    return timestamp.toString();
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
