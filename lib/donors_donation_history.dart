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
          .get();

      final List<Map<String, dynamic>> donations = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Get total quantity from categorySummary or calculate from items
        int totalQuantity = 0;
        if (data['categorySummary'] != null) {
          final categorySummary = Map<String, dynamic>.from(data['categorySummary']);
          totalQuantity = categorySummary.values.fold(0, (sum, qty) => sum + (qty as int));
        } else if (data['totalQuantity'] != null) {
          totalQuantity = data['totalQuantity'] as int;
        } else {
          // Fallback: try to get from items collection
          try {
            final itemsSnapshot = await doc.reference.collection('items').get();
            for (final itemDoc in itemsSnapshot.docs) {
              final itemData = itemDoc.data();
              totalQuantity += itemData['quantity'] as int? ?? 0;
            }
          } catch (e) {
            print('Error fetching items for donation ${doc.id}: $e');
          }
        }

        // Get categories
        List<String> categories = [];
        if (data['categories'] != null) {
          categories = List<String>.from(data['categories']);
        } else if (data['category'] != null) {
          categories = [data['category'] as String];
        }

        donations.add({
          'id': doc.id,
          'date': (data['timestamp'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? 'Unknown date',
          'categories': categories,
          'category': categories.isNotEmpty ? categories.first : 'Unknown',
          'quantity': totalQuantity,
          'status': data['status'] ?? 'pending',
          'title': data['title'] ?? 'Donation',
          'deliveryOption': data['deliveryOption'] ?? 'Unknown',
          'location': data['location'] ?? 'Unknown location',
          'pickupStation': data['pickupStation'],
          'assignedTo': data['assignedTo'],
        });
      }

      // Sort by timestamp manually
      donations.sort((a, b) {
        final aDate = a['date'] as String;
        final bDate = b['date'] as String;
        return bDate.compareTo(aDate); // Most recent first
      });

      setState(() {
        _donations = donations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching donations: $e');
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
