import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DonorsDonationHistoryPage extends StatefulWidget {
  const DonorsDonationHistoryPage({super.key});

  @override
  State<DonorsDonationHistoryPage> createState() => _DonorsDonationHistoryPageState();
}

class _DonorsDonationHistoryPageState extends State<DonorsDonationHistoryPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _donations = [];

  @override
  void initState() {
    super.initState();
    _waitForUserAndFetchDonations();
  }

  Future<void> _waitForUserAndFetchDonations() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      user = await FirebaseAuth.instance.authStateChanges().firstWhere((user) => user != null);
    }
    _fetchDonations(user!);
  }

  Future<void> _fetchDonations(User user) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _donations = [];
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      final donations = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'date': (data['timestamp'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? 'Unknown date',
          'category': data['category'] ?? 'Unknown',
          'quantity': _parseQuantity(data['quantity']),
          'status': data['status'] ?? 'pending',
          'title': data['title'] ?? 'No title',
          'deliveryOption': data['deliveryOption'] ?? 'Unknown',
        };
      }).toList();

      setState(() {
        _donations = donations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load your donation history. '
            'Please check your internet connection and try again.';
      });
    }
  }

  int _parseQuantity(dynamic quantity) {
    if (quantity is int) return quantity;
    if (quantity is num) return quantity.toInt();
    return int.tryParse(quantity?.toString() ?? '0') ?? 0;
  }

  List<Map<String, dynamic>> get _badges {
    int donationCount = _donations.length;

    return [
      {
        'name': 'Bronze Donor',
        'description': 'Donated at least 5 times',
        'earned': donationCount >= 5,
        'icon': Icons.emoji_events,
      },
      {
        'name': 'Silver Donor',
        'description': 'Donated at least 15 times',
        'earned': donationCount >= 15,
        'icon': Icons.emoji_events_outlined,
      },
      {
        'name': 'Gold Donor',
        'description': 'Donated at least 30 times',
        'earned': donationCount >= 30,
        'icon': Icons.workspace_premium_outlined,
      },
    ];
  }

  Map<String, int> getDonationTotals() {
    final Map<String, int> totals = {};
    for (var donation in _donations) {
      final category = donation['category'] as String? ?? 'Unknown';
      final quantity = donation['quantity'] as int? ?? 0;
      totals[category] = (totals[category] ?? 0) + quantity;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final totals = getDonationTotals();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation History'),
        backgroundColor: Colors.deepPurple, // Changed here to deep purple
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              User? user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await _fetchDonations(user);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorMessage()
            : _donations.isEmpty
            ? const Center(
          child: Text(
            'You have no donation records yet. Start donating to earn badges!',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBadgesSection(),
            const SizedBox(height: 24),
            _buildStatisticsSection(totals),
            const SizedBox(height: 24),
            Expanded(child: _buildDonationsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _errorMessage ?? '',
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _waitForUserAndFetchDonations,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Badges',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final badge = _badges[index];
              return Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                    badge['earned'] ? Colors.amber : Colors.grey[300],
                    child: Icon(
                      badge['icon'],
                      size: 36,
                      color: badge['earned'] ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 100,
                    child: Text(
                      badge['name'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: badge['earned'] ? Colors.black : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsSection(Map<String, int> totals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Donation Statistics',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...totals.entries.map(
              (entry) => Text(
            '${entry.key}: ${entry.value} items donated',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDonationsList() {
    return ListView.separated(
      itemCount: _donations.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final donation = _donations[index];
        return ListTile(
          leading: const Icon(Icons.card_giftcard),
          title:
          Text('${donation['category']} — Quantity: ${donation['quantity']}'),
          subtitle:
          Text('Date: ${donation['date']} - Status: ${donation['status']}'),
        );
      },
    );
  }
}
