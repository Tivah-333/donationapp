import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ViewReportsPage extends StatefulWidget {
  const ViewReportsPage({super.key});

  @override
  State<ViewReportsPage> createState() => _ViewReportsPageState();
}

class _ViewReportsPageState extends State<ViewReportsPage> {
  int totalDonors = 0;
  int totalOrganizations = 0;
  int totalDonations = 0;
  Map<String, int> categoryCounts = {};
  List<FlSpot> donationSpots = [];

  String selectedCategory = 'All';
  DateTime? fromDate;
  DateTime? toDate;

  final List<String> _categories = ['All', 'Food', 'Clothes', 'School Materials', 'Other'];

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  Future<void> fetchReports() async {
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final donationsSnapshot = await FirebaseFirestore.instance
        .collection('donations')
        .orderBy('timestamp', descending: true)
        .get();

    int donors = 0, orgs = 0;
    for (var doc in usersSnapshot.docs) {
      final role = doc['role'];
      if (role == 'Donor') donors++;
      if (role == 'Organization') orgs++;
    }

    Map<String, int> categoryMap = {};
    Map<DateTime, int> dailyCounts = {};
    int validDonationCount = 0;

    for (var doc in donationsSnapshot.docs) {
      final timestamp = doc['timestamp']?.toDate();
      final category = doc['category'] ?? 'Unknown';

      if (timestamp == null) continue;
      if (fromDate != null && timestamp.isBefore(fromDate!)) continue;
      if (toDate != null && timestamp.isAfter(toDate!)) continue;
      if (selectedCategory != 'All' && selectedCategory != category) continue;

      validDonationCount++;
      categoryMap[category] = (categoryMap[category] ?? 0) + 1;

      final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }

    final sortedDates = dailyCounts.keys.toList()..sort();
    List<FlSpot> spots = [];
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailyCounts[sortedDates[i]]!.toDouble()));
    }

    setState(() {
      totalDonors = donors;
      totalOrganizations = orgs;
      totalDonations = validDonationCount;
      categoryCounts = categoryMap;
      donationSpots = spots;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        fromDate = picked.start;
        toDate = picked.end;
      });
      fetchReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDonations = totalDonations > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('View Reports'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedCategory = value);
                        fetchReports();
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Category Filter'),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _selectDateRange,
                  child: const Text('Select Date Range'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('👥 Total Donors: $totalDonors', style: const TextStyle(fontSize: 16)),
            Text('🏢 Total Organizations: $totalOrganizations', style: const TextStyle(fontSize: 16)),
            Text('🎁 Total Donations: $totalDonations', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),

            if (!hasDonations)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'No donations registered yet.\nPlease check back later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
              ),

            if (hasDonations) ...[
              const Text('🎯 Donations by Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...categoryCounts.entries.map((e) => Text('${e.key}: ${e.value}')),
              const SizedBox(height: 24),

              const Text('📈 Donations Over Time',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: donationSpots,
                        isCurved: true,
                        dotData: FlDotData(show: false),
                        color: Colors.deepPurple,
                        barWidth: 3,
                      )
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
