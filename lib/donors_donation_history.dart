import 'package:flutter/material.dart';

class DonorsDonationHistoryPage extends StatelessWidget {
  const DonorsDonationHistoryPage({super.key});

  // Non-money donations sample data WITHOUT blankets
  final List<Map<String, dynamic>> donations = const [
    {
      'date': '2025-07-01',
      'category': 'Clothes',
      'quantity': 5,
      'status': 'Delivered',
    },
    {
      'date': '2025-06-15',
      'category': 'Food Supplies',
      'quantity': 10,
      'status': 'Pending',
    },
    {
      'date': '2025-05-20',
      'category': 'Clothes',
      'quantity': 3,
      'status': 'Delivered',
    },
  ];

  // Dummy badges data
  final List<Map<String, dynamic>> badges = const [
    {
      'name': 'Bronze Donor',
      'description': 'Donated at least 3 times',
      'earned': true,
      'icon': Icons.emoji_events,
    },
    {
      'name': 'Silver Donor',
      'description': 'Donated at least 10 times',
      'earned': false,
      'icon': Icons.emoji_events_outlined,
    },
    {
      'name': 'Gold Donor',
      'description': 'Donated at least 20 times',
      'earned': false,
      'icon': Icons.workspace_premium_outlined,
    },
  ];

  // Calculate total quantities per category
  Map<String, int> getDonationTotals() {
    final Map<String, int> totals = {};
    for (var donation in donations) {
      final category = donation['category'] as String;
      final quantity = donation['quantity'] as int;
      totals[category] = (totals[category] ?? 0) + quantity;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final totals = getDonationTotals();

    return Scaffold(
      appBar: AppBar(title: const Text('Donation History')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Badges Section
            _buildBadgesSection(),

            const SizedBox(height: 24),

            // Statistics Section
            _buildStatisticsSection(totals),

            const SizedBox(height: 24),

            // Donations List
            Expanded(child: _buildDonationsList()),
          ],
        ),
      ),
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
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final badge = badges[index];
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

  Widget _buildDonationsList() {
    return ListView.separated(
      itemCount: donations.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final donation = donations[index];
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
