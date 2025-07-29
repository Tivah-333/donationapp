import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DonationStatisticsPage extends StatefulWidget {
  const DonationStatisticsPage({super.key});

  @override
  State<DonationStatisticsPage> createState() => _DonationStatisticsPageState();
}

class _DonationStatisticsPageState extends State<DonationStatisticsPage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  
  // Statistics data
  int totalAssigned = 0;
  int pendingCount = 0;
  int pickedUpCount = 0;
  int droppedOffCount = 0;
  
  // Donations by status
  List<Map<String, dynamic>> pendingDonations = [];
  List<Map<String, dynamic>> pickedUpDonations = [];
  List<Map<String, dynamic>> droppedOffDonations = [];

  @override
  void initState() {
    super.initState();
    _loadOrganizationStatistics();
  }

  Future<void> _loadOrganizationStatistics() async {
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Get all donations assigned to this organization
      final donationsSnapshot = await FirebaseFirestore.instance
          .collection('donations')
          .where('assignedTo', isEqualTo: user!.uid)
          .get();

      final List<Map<String, dynamic>> allDonations = [];
      
      for (final doc in donationsSnapshot.docs) {
        final data = doc.data();
        
        // Extract category from categorySummary or fallback to category field
        String category = 'Unknown';
        if (data['categorySummary'] != null) {
          final categorySummary = data['categorySummary'] as Map<String, dynamic>;
          // Get the first category from categorySummary
          if (categorySummary.isNotEmpty) {
            category = categorySummary.keys.first;
          }
        } else if (data['category'] != null) {
          category = data['category'] as String;
        } else if (data['categories'] != null) {
          final categories = data['categories'] as List<dynamic>;
          if (categories.isNotEmpty) {
            category = categories.first as String;
          }
        }
        
        print('📊 Processing donation ${doc.id}: category=$category, status=${data['status']}');
        
        final donation = {
          'id': doc.id,
          'donorEmail': data['donorEmail'] ?? 'Unknown',
          'location': data['location'] ?? 'Unknown',
          'deliveryOption': data['deliveryOption'] ?? 'Unknown',
          'pickupStation': data['pickupStation'],
          'quantity': data['quantity'] ?? 0,
          'category': category,
          'title': data['title'] ?? 'Unknown',
          'assignedAt': data['assignedAt'] as Timestamp?,
          'pickedUpAt': data['pickedUpAt'] as Timestamp?,
          'droppedOffAt': data['droppedOffAt'] as Timestamp?,
          'status': data['status'] ?? 'approved',
        };
        
        allDonations.add(donation);
      }

      // Also get dropped-off donations that might not be assigned to this organization
      // but were processed by this organization
      final droppedOffSnapshot = await FirebaseFirestore.instance
          .collection('donations')
          .where('status', isEqualTo: 'dropped_off')
          .get();

      print('🔍 Found ${droppedOffSnapshot.docs.length} dropped-off donations total');

      for (final doc in droppedOffSnapshot.docs) {
        final data = doc.data();
        
        // Only include if this organization was involved in processing
        if (data['assignedTo'] == user!.uid || 
            data['processedBy'] == user!.uid ||
            data['organizationId'] == user!.uid) {
          
          print('✅ Including dropped-off donation ${doc.id} for organization ${user!.uid}');
          
          // Extract category from categorySummary or fallback to category field
          String category = 'Unknown';
          if (data['categorySummary'] != null) {
            final categorySummary = data['categorySummary'] as Map<String, dynamic>;
            // Get the first category from categorySummary
            if (categorySummary.isNotEmpty) {
              category = categorySummary.keys.first;
            }
          } else if (data['category'] != null) {
            category = data['category'] as String;
          } else if (data['categories'] != null) {
            final categories = data['categories'] as List<dynamic>;
            if (categories.isNotEmpty) {
              category = categories.first as String;
            }
          }
          
          print('📊 Processing dropped-off donation ${doc.id}: category=$category');
          
          final donation = {
            'id': doc.id,
            'donorEmail': data['donorEmail'] ?? 'Unknown',
            'location': data['location'] ?? 'Unknown',
            'deliveryOption': data['deliveryOption'] ?? 'Unknown',
            'pickupStation': data['pickupStation'],
            'quantity': data['quantity'] ?? 0,
            'category': category,
            'title': data['title'] ?? 'Unknown',
            'assignedAt': data['assignedAt'] as Timestamp?,
            'pickedUpAt': data['pickedUpAt'] as Timestamp?,
            'droppedOffAt': data['droppedOffAt'] as Timestamp?,
            'status': data['status'] ?? 'dropped_off',
          };
          
          // Only add if not already in the list
          if (!allDonations.any((d) => d['id'] == donation['id'])) {
            allDonations.add(donation);
          }
        } else {
          print('❌ Excluding dropped-off donation ${doc.id} - not processed by ${user!.uid}');
        }
      }

      // Also check donation_requests collection for this organization
      print('🔍 Checking donation_requests collection for organization ${user!.uid}');
      final donationRequestsSnapshot = await FirebaseFirestore.instance
          .collection('donation_requests')
          .where('organizationId', isEqualTo: user!.uid)
          .get();

      print('📋 Found ${donationRequestsSnapshot.docs.length} donation requests for organization');

      for (final doc in donationRequestsSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'pending';
        
        print('📊 Processing donation request ${doc.id}: status=$status, title=${data['title']}');
        
        // Only include if it's a dropped-off request
        if (status == 'dropped_off') {
          print('✅ Including dropped-off donation request ${doc.id}');
          
          final donation = {
            'id': 'request_${doc.id}', // Prefix to avoid conflicts
            'donorEmail': 'Organization Request', // These are organization requests, not donor donations
            'location': data['location'] ?? 'Unknown',
            'deliveryOption': data['deliveryMethod'] ?? 'Unknown',
            'pickupStation': data['pickupStation'],
            'quantity': data['quantity'] ?? 0,
            'category': data['category'] ?? 'Unknown',
            'title': data['title'] ?? 'Unknown',
            'assignedAt': data['assignedAt'] as Timestamp?,
            'pickedUpAt': data['organizationReviewedAt'] as Timestamp?, // Use organizationReviewedAt for picked up
            'droppedOffAt': data['organizationReviewedAt'] as Timestamp?, // Use organizationReviewedAt for dropped off
            'status': status,
          };
          
          // Only add if not already in the list
          if (!allDonations.any((d) => d['id'] == donation['id'])) {
            allDonations.add(donation);
          }
        }
      }

      // Categorize donations by status
      pendingDonations = allDonations.where((d) => d['status'] == 'approved').toList();
      pickedUpDonations = allDonations.where((d) => d['status'] == 'picked_up').toList();
      droppedOffDonations = allDonations.where((d) => d['status'] == 'dropped_off').toList();

      // Update counts
      totalAssigned = allDonations.length;
      pendingCount = pendingDonations.length;
      pickedUpCount = pickedUpDonations.length;
      droppedOffCount = droppedOffDonations.length;

      print('📈 Final statistics:');
      print('  - Total assigned: $totalAssigned');
      print('  - Pending: $pendingCount');
      print('  - Picked up: $pickedUpCount');
      print('  - Dropped off: $droppedOffCount');

    } catch (e) {
      print('Error loading organization statistics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Donation Statistics'),
          backgroundColor: Colors.deepPurple,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Picked Up'),
              Tab(text: 'Dropped Off'),
            ],
            indicatorColor: Colors.white,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadOrganizationStatistics,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Statistics Cards
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('Total Assigned', totalAssigned, Colors.blue),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard('Pending', pendingCount, Colors.orange),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard('Picked Up', pickedUpCount, Colors.purple),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard('Dropped Off', droppedOffCount, Colors.green),
                        ),
                      ],
                    ),
                  ),
                  
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildDonationsList(pendingDonations, 'approved'),
                        _buildDonationsList(pickedUpDonations, 'picked_up'),
                        _buildDonationsList(droppedOffDonations, 'dropped_off'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationsList(List<Map<String, dynamic>> donations, String status) {
    if (donations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getStatusIcon(status),
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${status.replaceAll('_', ' ')} donations',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: donations.length,
      itemBuilder: (context, index) {
        final donation = donations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text('${donation['title']} from ${donation['donorEmail']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quantity: ${donation['quantity']} items'),
                Text('Category: ${donation['category']}'),
                Text('Location: ${donation['location']}'),
                Text('Delivery: ${donation['deliveryOption'] == 'Pickup' ? 'Pickup' : 'Drop-off'}'),
                if (donation['pickupStation'] != null)
                  Text('Pickup Station: ${donation['pickupStation']}'),
                if (donation['assignedAt'] != null)
                  Text('Assigned: ${DateFormat('MMM d, y • h:mm a').format(donation['assignedAt'].toDate())}'),
                if (donation['pickedUpAt'] != null)
                  Text('Picked Up: ${DateFormat('MMM d, y • h:mm a').format(donation['pickedUpAt'].toDate())}'),
                if (donation['droppedOffAt'] != null)
                  Text('Dropped Off: ${DateFormat('MMM d, y • h:mm a').format(donation['droppedOffAt'].toDate())}'),
              ],
            ),
            trailing: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
          ),
        );
      },
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.schedule;
      case 'picked_up':
        return Icons.local_shipping;
      case 'dropped_off':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.orange;
      case 'picked_up':
        return Colors.purple;
      case 'dropped_off':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
