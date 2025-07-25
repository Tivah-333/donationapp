import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DonationStatisticsPage extends StatefulWidget {
  const DonationStatisticsPage({super.key});

  @override
  State<DonationStatisticsPage> createState() => _DonationStatisticsPageState();
}

class _DonationStatisticsPageState extends State<DonationStatisticsPage> {
  final Map<String, Duration> dateRanges = {
    'Last 7 days': Duration(days: 7),
    'Last 30 days': Duration(days: 30),
    'Last 90 days': Duration(days: 90),
    'All time': Duration(days: 365 * 10),
  };

  String selectedRangeLabel = 'Last 7 days';
  DateTimeRange? customDateRange;

  String searchQuery = '';
  TextEditingController searchController = TextEditingController();

  int totalDonations = 0;
  int approved = 0;
  int rejected = 0;
  int pending = 0;
  int delivered = 0;

  Map<String, int> itemCounts = {};

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  DateTime get startDate {
    if (selectedRangeLabel == 'All time') {
      return DateTime(2000);
    } else if (customDateRange != null) {
      return customDateRange!.start;
    } else {
      return DateTime.now().subtract(dateRanges[selectedRangeLabel]!);
    }
  }

  DateTime get endDate {
    if (customDateRange != null) {
      return customDateRange!.end;
    } else {
      return DateTime.now();
    }
  }

  Future<void> _fetchStatistics() async {
    setState(() {
      loading = true;
      totalDonations = 0;
      approved = 0;
      rejected = 0;
      pending = 0;
      delivered = 0;
      itemCounts = {};
    });

    final donationsRef = FirebaseFirestore.instance.collection('donations');

    Query query = donationsRef
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    if (searchQuery.isNotEmpty) {
      final snapshot = await query.get();
      final docs = snapshot.docs;
      final filteredDocs = docs.where((doc) {
        final itemName = (doc['itemName'] ?? '').toString().toLowerCase();
        return itemName.contains(searchQuery.toLowerCase());
      }).toList();

      _calculateStatsFromDocs(filteredDocs);
    } else {
      final snapshot = await query.get();
      _calculateStatsFromDocs(snapshot.docs);
    }

    setState(() {
      loading = false;
    });
  }

  void _calculateStatsFromDocs(List<QueryDocumentSnapshot> docs) {
    totalDonations = docs.length;
    approved = 0;
    rejected = 0;
    pending = 0;
    delivered = 0;

    itemCounts = {};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      final status = (data['status'] ?? '').toString().toLowerCase();
      final itemName = (data['itemName'] ?? '').toString();
      final quantity = (data['quantity'] ?? 1) as int;

      switch (status) {
        case 'approved':
          approved += 1;
          break;
        case 'rejected':
          rejected += 1;
          break;
        case 'pending':
          pending += 1;
          break;
        case 'delivered':
          delivered += 1;
          break;
      }

      itemCounts[itemName] = (itemCounts[itemName] ?? 0) + quantity;
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: customDateRange,
    );
    if (picked != null) {
      setState(() {
        customDateRange = picked;
        selectedRangeLabel = 'Custom Range';
      });
      await _fetchStatistics();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value.trim();
    });
    _fetchStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation Statistics'),
        backgroundColor: Colors.deepPurple, // updated to deep purple
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchStatistics,
            color: Colors.white,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedRangeLabel,
                    items: dateRanges.keys
                        .map((label) => DropdownMenuItem(
                      value: label,
                      child: Text(label),
                    ))
                        .toList()
                      ..add(DropdownMenuItem(
                        value: 'Custom Range',
                        child: const Text('Custom Range'),
                      )),
                    onChanged: (val) async {
                      if (val == 'Custom Range') {
                        await _selectCustomDateRange();
                      } else if (val != null) {
                        setState(() {
                          selectedRangeLabel = val;
                          customDateRange = null;
                        });
                        await _fetchStatistics();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildStatCard('Total Donations Received', totalDonations, Colors.blue),
                  _buildStatCard('Approved', approved, Colors.green),
                  _buildStatCard('Rejected', rejected, Colors.red),
                  _buildStatCard('Pending', pending, Colors.orange),
                  _buildStatCard('Delivered', delivered, Colors.purple),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search Donation Item',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: itemCounts.isEmpty
                  ? Center(child: loading ? const CircularProgressIndicator() : const Text('No donations found'))
                  : ListView(
                children: itemCounts.entries
                    .map(
                      (e) => ListTile(
                    title: Text(e.key),
                    trailing: Text(e.value.toString()),
                  ),
                )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}
