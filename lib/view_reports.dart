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
  DateTime? fromDate;
  DateTime? toDate;
  String selectedCategory = 'All';
  bool isLoading = true;

  // Statistics
  int totalDonors = 0;
  int totalOrganizations = 0;
  int totalDonations = 0;
  int pendingDonations = 0;
  int approvedDonations = 0;
  int rejectedDonations = 0;
  int assignedDonations = 0;
  int deliveredDonations = 0;
  int pickedUpDonations = 0;
  int droppedOffDonations = 0;
  Map<String, int> categoryStats = {};
  Map<DateTime, int> dailyDonations = {};

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  Future<void> fetchReports() async {
    setState(() => isLoading = true);

    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final donationsSnapshot = await FirebaseFirestore.instance.collection('donations').get();

      // Count users by role
      int donors = 0, orgs = 0;
      for (var doc in usersSnapshot.docs) {
        final role = doc.data()['role'];
        if (role == 'Donor') donors++;
        if (role == 'Organization') orgs++;
      }

      // Process donations
      Map<String, int> categoryMap = {};
      Map<DateTime, int> dailyCounts = {};
      int validDonationCount = 0;
      int pending = 0, approved = 0, rejected = 0, assigned = 0, pickedUp = 0, droppedOff = 0;

      for (var doc in donationsSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp']?.toDate();
        final category = data['category'] ?? 'Unknown';
        final status = data['status'] ?? 'pending';

        if (timestamp == null) continue;
        if (fromDate != null && timestamp.isBefore(fromDate!)) continue;
        if (toDate != null && timestamp.isAfter(toDate!)) continue;
        if (selectedCategory != 'All' && selectedCategory != category) continue;

        validDonationCount++;
        categoryMap[category] = (categoryMap[category] ?? 0) + 1;

        // Count by status
        switch (status) {
          case 'pending':
            pending++;
            break;
          case 'approved':
            approved++;
            break;
          case 'rejected':
            rejected++;
            break;
          case 'assigned':
            assigned++;
            break;
          case 'picked_up':
            pickedUp++;
            break;
          case 'dropped_off':
            droppedOff++;
            break;
        }

        final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
        dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
      }

      setState(() {
        totalDonors = donors;
        totalOrganizations = orgs;
        totalDonations = validDonationCount;
        pendingDonations = pending;
        approvedDonations = approved;
        rejectedDonations = rejected;
        assignedDonations = assigned;
        deliveredDonations = pickedUp + droppedOff; // Combined for summary card
        pickedUpDonations = pickedUp;
        droppedOffDonations = droppedOff;
        categoryStats = categoryMap;
        dailyDonations = dailyCounts;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching reports: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchReports,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 20),
                  _buildDonationStatusChart(),
                  const SizedBox(height: 20),
                  _buildCategoryChart(),
                  const SizedBox(height: 20),
                  _buildDailyDonationsChart(),
                  const SizedBox(height: 20),
                  _buildDetailedStats(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _buildSummaryCard('Total Donors', totalDonors.toString(), Icons.people, Colors.blue),
        _buildSummaryCard('Total Organizations', totalOrganizations.toString(), Icons.business, Colors.green),
        _buildSummaryCard('Total Donations', totalDonations.toString(), Icons.favorite, Colors.red),
        _buildSummaryCard('Picked Up/Dropped Off', (deliveredDonations + assignedDonations).toString(), Icons.check_circle, Colors.orange),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationStatusChart() {
    final statusData = [
      {'status': 'Pending', 'count': pendingDonations, 'color': Colors.orange},
      {'status': 'Approved', 'count': approvedDonations, 'color': Colors.blue},
      {'status': 'Rejected', 'count': rejectedDonations, 'color': Colors.red},
      {'status': 'Assigned', 'count': assignedDonations, 'color': Colors.purple},
      {'status': 'Picked Up', 'count': pickedUpDonations, 'color': Colors.green},
      {'status': 'Dropped Off', 'count': droppedOffDonations, 'color': Colors.teal},
    ];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Donation Status Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: statusData.map((data) {
                    final count = data['count'] as int;
                    final percentage = totalDonations > 0 
                        ? count / totalDonations * 100 
                        : 0.0;
                    return PieChartSectionData(
                      value: count.toDouble(),
                      title: '${data['count']}\n${percentage.toStringAsFixed(1)}%',
                      color: data['color'] as Color,
                      radius: 70,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  centerSpaceRadius: 50,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              children: statusData.map((data) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: data['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('${data['status']}: ${data['count']}'),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    // Standard categories used throughout the app
    final List<String> standardCategories = [
      'Clothes',
      'Food Supplies',
      'Medical Supplies',
      'School Supplies',
      'Hygiene Products',
      'Electronics',
      'Furniture',
      'Others',
    ];

    // Create a map with all standard categories, defaulting to 0 if not in categoryStats
    final Map<String, int> allCategories = {};
    for (final category in standardCategories) {
      allCategories[category] = categoryStats[category] ?? 0;
    }

    // Sort by count (descending) and then by category name for consistency
    final sortedCategories = allCategories.entries.toList()
      ..sort((a, b) {
        if (b.value != a.value) {
          return b.value.compareTo(a.value);
        }
        return a.key.compareTo(b.key);
      });
    
    // Limit to top 6 categories to prevent overlap
    final displayCategories = sortedCategories.take(6).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Donations by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: displayCategories.isNotEmpty ? displayCategories.first.value.toDouble() : 1.0,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < displayCategories.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                displayCategories[value.toInt()].key,
                                style: const TextStyle(fontSize: 9),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString());
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(displayCategories.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: displayCategories[index].value.toDouble(),
                          color: Colors.blue,
                          width: 16,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyDonationsChart() {
    if (dailyDonations.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No daily donation data available'),
        ),
      );
    }

    final sortedDates = dailyDonations.keys.toList()..sort();
    final spots = sortedDates.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), dailyDonations[entry.value]!.toDouble());
    }).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Donations Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < sortedDates.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('MMM d').format(sortedDates[value.toInt()]),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString());
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStats() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detailed Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Total Users', (totalDonors + totalOrganizations).toString()),
            _buildStatRow('Donors', totalDonors.toString()),
            _buildStatRow('Organizations', totalOrganizations.toString()),
            _buildStatRow('Total Donations', totalDonations.toString()),
            _buildStatRow('Pending Donations', pendingDonations.toString()),
            _buildStatRow('Approved Donations', approvedDonations.toString()),
            _buildStatRow('Rejected Donations', rejectedDonations.toString()),
            _buildStatRow('Assigned Donations', assignedDonations.toString()),
            _buildStatRow('Picked Up Donations', pickedUpDonations.toString()),
            _buildStatRow('Dropped Off Donations', droppedOffDonations.toString()),
            if (fromDate != null || toDate != null) ...[
              const SizedBox(height: 16),
              Text(
                'Filter: ${fromDate != null ? DateFormat('MMM d, y').format(fromDate!) : 'All time'} - ${toDate != null ? DateFormat('MMM d, y').format(toDate!) : 'Now'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Reports'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('From Date'),
              subtitle: Text(fromDate != null ? DateFormat('MMM d, y').format(fromDate!) : 'Select date'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: fromDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => fromDate = date);
                }
              },
            ),
            ListTile(
              title: const Text('To Date'),
              subtitle: Text(toDate != null ? DateFormat('MMM d, y').format(toDate!) : 'Select date'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: toDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => toDate = date);
                }
              },
            ),
            ListTile(
              title: const Text('Category'),
              subtitle: Text(selectedCategory),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Select Category'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        'All',
                        'Clothes',
                        'Food Supplies',
                        'Medical Supplies',
                        'School Supplies',
                        'Hygiene Products',
                        'Electronics',
                        'Furniture',
                        'Others',
                      ].map((category) {
                        return ListTile(
                          title: Text(category),
                          onTap: () {
                            setState(() => selectedCategory = category);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                fromDate = null;
                toDate = null;
                selectedCategory = 'All';
              });
              Navigator.pop(context);
              fetchReports();
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              fetchReports();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
