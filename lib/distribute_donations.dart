import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'services/donation_matching_service.dart';
import 'services/notification_service.dart';

class DistributeDonationsPage extends StatefulWidget {
  final VoidCallback? onDonationAssigned;
  
  const DistributeDonationsPage({Key? key, this.onDonationAssigned}) : super(key: key);

  @override
  State<DistributeDonationsPage> createState() => _DistributeDonationsPageState();
}

class _DistributeDonationsPageState extends State<DistributeDonationsPage> {
  Map<String, String?> _selectedOrganizations = {};
  Map<String, Map<String, int>> _categoryTitleAvailability = {};
  List<String> _categories = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';

  final List<String> _allCategories = [
    'All',
    'Clothes',
    'Food Supplies',
    'Medical Supplies',
    'School Supplies',
    'Hygiene Products',
    'Electronics',
    'Furniture',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _loadCategoryData();
  }

  Future<void> _loadCategoryData() async {
    setState(() => _isLoading = true);
    
    try {
      // Get all pending and approved donations
      final donationsSnapshot = await FirebaseFirestore.instance
          .collection('donations')
          .where('status', whereIn: ['pending', 'approved'])
          .get();

      final Map<String, Map<String, int>> categoryTitleTotals = {};
      final Set<String> categories = {};

      // Process all donations to build availability
      for (final doc in donationsSnapshot.docs) {
        final data = doc.data();
        final categorySummary = data['categorySummary'] as Map<String, dynamic>?;
        final title = data['title'] as String? ?? 'Unknown';
        final status = data['status'] as String? ?? 'pending';
        final assignedTo = data['assignedTo'] as String?;
        
        if (categorySummary != null) {
          for (final entry in categorySummary.entries) {
            final category = entry.key as String;
            final totalQuantity = entry.value as int? ?? 0;
            
            // Calculate available quantity based on assignment status
            int availableQuantity = 0;
            
            if (status == 'pending') {
              // Pending donations are fully available
              availableQuantity = totalQuantity;
              print('  📦 Donation ${doc.id}: $title ($category) - PENDING - $totalQuantity available');
            } else if (status == 'approved') {
              // Check assigned quantities for this category
              final assignedQuantities = data['assignedQuantities'] as Map<String, dynamic>? ?? {};
              final assignedQuantity = assignedQuantities[category] as int? ?? 0;
              
              // Available quantity is total minus assigned
              availableQuantity = totalQuantity - assignedQuantity;
              print('  📦 Donation ${doc.id}: $title ($category) - APPROVED - $totalQuantity total, $assignedQuantity assigned, $availableQuantity available');
            }
            
            if (availableQuantity > 0) {
              categories.add(category);
              categoryTitleTotals[category] ??= {};
              categoryTitleTotals[category]![title] = (categoryTitleTotals[category]![title] ?? 0) + availableQuantity;
            }
          }
        }
      }

      setState(() {
        _categoryTitleAvailability = categoryTitleTotals;
        _categories = ['All', ...categories.toList()..sort()];
        _isLoading = false;
      });

      print('📊 Loaded category data:');
      for (final category in categoryTitleTotals.keys) {
        print('  $category:');
        for (final title in categoryTitleTotals[category]!.keys) {
          print('    $title: ${categoryTitleTotals[category]![title]} available');
        }
      }
    } catch (e) {
      print('Error loading category data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignDonationToOrganization(String category, String title, String organizationId, String organizationName) async {
    setState(() => _isLoading = true);

    try {
      print('🎯 Starting assignment of $title ($category) to organization $organizationId');
      
      // Get the organization's request for this specific title and category
      // Look for both pending and approved requests (approved requests can still be assigned)
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('donation_requests')
          .where('organizationId', isEqualTo: organizationId)
          .where('category', isEqualTo: category)
          .where('title', isEqualTo: title)
          .where('status', whereIn: ['pending', 'approved'])
          .get();

      if (requestsSnapshot.docs.isEmpty) {
        throw Exception('This organization has no pending or approved requests for $title in $category.');
      }

      final requestData = requestsSnapshot.docs.first.data();
      final requestedQuantity = requestData['quantity'] as int? ?? 0;
      final availableQuantity = _categoryTitleAvailability[category]?[title] ?? 0;

      print('📋 Organization requested $requestedQuantity items for $title ($category), available: $availableQuantity');

      if (requestedQuantity > availableQuantity) {
        throw Exception('Insufficient $title available. Requested: $requestedQuantity, Available: $availableQuantity');
      }

      // Find a donation that has this title and category with sufficient available quantity
      final donationsSnapshot = await FirebaseFirestore.instance
          .collection('donations')
          .where('status', whereIn: ['pending', 'approved'])
          .get();

      String? donationId;
      int? availableInDonation;
      
      for (final doc in donationsSnapshot.docs) {
        final data = doc.data();
        final donationTitle = data['title'] as String?;
        final categorySummary = data['categorySummary'] as Map<String, dynamic>?;
        final status = data['status'] as String? ?? 'pending';
        
        if (donationTitle == title && categorySummary != null && categorySummary.containsKey(category)) {
          final totalQuantity = categorySummary[category] as int? ?? 0;
          int availableQuantity = 0;
          
          if (status == 'pending') {
            availableQuantity = totalQuantity;
          } else if (status == 'approved') {
            final assignedQuantities = data['assignedQuantities'] as Map<String, dynamic>? ?? {};
            final assignedQuantity = assignedQuantities[category] as int? ?? 0;
            availableQuantity = totalQuantity - assignedQuantity;
          }
          
          if (availableQuantity >= requestedQuantity) {
            donationId = doc.id;
            availableInDonation = availableQuantity;
            print('🔍 Found donation $donationId with $availableInDonation available items');
            break;
          }
        }
      }

      if (donationId == null) {
        throw Exception('No donation found with title "$title" in category "$category" with sufficient available quantity ($requestedQuantity needed)');
      }

      // Get the current donation data to check if it's already partially assigned
      final currentDonationDoc = await FirebaseFirestore.instance.collection('donations').doc(donationId).get();
      final currentDonationData = currentDonationDoc.data()!;
      final currentAssignedQuantities = currentDonationData['assignedQuantities'] as Map<String, dynamic>? ?? {};
      
      // Update assigned quantities for this category
      final currentAssignedForCategory = currentAssignedQuantities[category] as int? ?? 0;
      final newAssignedForCategory = currentAssignedForCategory + requestedQuantity;
      
      // Update the assigned quantities map
      final updatedAssignedQuantities = Map<String, dynamic>.from(currentAssignedQuantities);
      updatedAssignedQuantities[category] = newAssignedForCategory;
      
      // Check if the entire donation is now assigned
      final categorySummary = currentDonationData['categorySummary'] as Map<String, dynamic>? ?? {};
      bool isFullyAssigned = true;
      
      for (final entry in categorySummary.entries) {
        final categoryKey = entry.key as String;
        final totalQuantity = entry.value as int? ?? 0;
        final assignedQuantity = updatedAssignedQuantities[categoryKey] as int? ?? 0;
        
        if (assignedQuantity < totalQuantity) {
          isFullyAssigned = false;
          break;
        }
      }
      
      // Update the donation
      final updateData = {
        'assignedTo': organizationId,
        'assignedAt': FieldValue.serverTimestamp(),
        'assignedQuantities': updatedAssignedQuantities,
        'status': isFullyAssigned ? 'assigned' : 'approved',
      };
      
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update(updateData);

      // Get the donation data for notifications
      final donationDoc = await FirebaseFirestore.instance.collection('donations').doc(donationId).get();
      final donationData = donationDoc.data()!;
      
      print('📦 Donation data for $donationId:');
      print('  - deliveryOption: ${donationData['deliveryOption']}');
      print('  - pickupStation: ${donationData['pickupStation']}');
      print('  - location: ${donationData['location']}');
      print('  - All keys: ${donationData.keys.toList()}');

      // Update the donation request status to 'assigned'
      for (final requestDoc in requestsSnapshot.docs) {
        final updateData = {
          'status': 'assigned',
          'assignedAt': FieldValue.serverTimestamp(),
          'deliveryMethod': donationData['deliveryOption'],
          'pickupStation': donationData['pickupStation'],
          'donorLocation': donationData['location'],
        };
        
        print('🔄 Updating donation request ${requestDoc.id} with data: $updateData');
        
        await requestDoc.reference.update(updateData);
        
        print('✅ Updated donation request ${requestDoc.id}');
      }

      // Update availability
      final newAvailable = availableQuantity - requestedQuantity;
      setState(() {
        _categoryTitleAvailability[category]![title] = newAvailable > 0 ? newAvailable : 0;
      });

      print('✅ Successfully assigned $requestedQuantity items of $title ($category) to $organizationName');
      print('📊 Updated assigned quantities: $updatedAssignedQuantities');
      print('📊 Is fully assigned: $isFullyAssigned');

      // Send notifications
      await NotificationService.sendDonationAssignedNotification(
        organizationId: organizationId,
        donationId: donationId,
        categories: [category],
        deliveryMethod: donationData['deliveryOption'],
        pickupStation: donationData['pickupStation'],
        donorLocation: donationData['location'],
        donationTitle: title,
        donationCategory: category,
      );

      // Remove the donor notification - donors should only be notified when donation is picked up or dropped off
      // final donorId = donationData['donorId'] as String?;
      // final donorEmail = donationData['donorEmail'] as String?;
      
      // if (donorId != null && donorEmail != null) {
      //   await NotificationService.sendDonationStatusNotification(
      //     donationId: donationId,
      //     status: 'approved',
      //     recipientId: donorId,
      //     recipientType: 'donor',
      //     donorEmail: donorEmail,
      //     organizationName: organizationName,
      //     donationTitle: title,
      //     donationCategory: category,
      //     deliveryMethod: donationData['deliveryOption'],
      //     pickupStation: donationData['pickupStation'],
      //     donorLocation: donationData['location'],
      //   );
      // }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assigned $requestedQuantity items of $title to $organizationName'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh data
      await _loadCategoryData();
      
    } catch (e) {
      print('❌ Error assigning donation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign donation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _getMatchingOrganizationsForTitle(String category, String title) async {
    try {
      print('🔍 Looking for organizations requesting $title in $category');
      
      // Get all organizations that have requested this title and category
      // Only look for pending and approved requests (assigned requests have already been fulfilled)
      final allOrganizationsWithRequests = await FirebaseFirestore.instance
          .collection('donation_requests')
          .where('category', isEqualTo: category)
          .where('title', isEqualTo: title)
          .where('status', whereIn: ['pending', 'approved'])
          .get();

      print('🔍 Found ${allOrganizationsWithRequests.docs.length} total organizations requesting $title in $category');
      
      // Debug: Show all requests for this specific title and category
      print('🔍 All requests for $title in $category:');
      for (final doc in allOrganizationsWithRequests.docs) {
        final data = doc.data();
        print('  - ${data['organizationId']}: ${data['title']} (${data['quantity']} items) - ${data['status']}');
      }
      
      // Debug: Show all requests for this organization
      final orgRequestsSnapshot = await FirebaseFirestore.instance
          .collection('donation_requests')
          .where('organizationId', isEqualTo: 'eU617pSdFmUAUWCvRhCZRTXWdRi1')
          .get();
      
      print('🔍 All requests for organization eU617pSdFmUAUWCvRhCZRTXWdRi1:');
      for (final doc in orgRequestsSnapshot.docs) {
        final data = doc.data();
        print('  - ${data['title']} (${data['category']}) - ${data['status']}');
      }
      
      // Debug: Show all organizations requesting Medical Supplies
      final medicalRequestsSnapshot = await FirebaseFirestore.instance
          .collection('donation_requests')
          .where('category', isEqualTo: 'Medical Supplies')
          .where('status', whereIn: ['pending', 'approved'])
          .get();
      
      print('🔍 All organizations requesting Medical Supplies:');
      for (final doc in medicalRequestsSnapshot.docs) {
        final data = doc.data();
        print('  - ${data['organizationId']}: ${data['title']} (${data['quantity']} items)');
      }
      
      final List<Map<String, dynamic>> organizations = [];
      final Set<String> processedOrgIds = <String>{};

      // Group requests by organization to avoid duplicates
      final Map<String, List<QueryDocumentSnapshot>> orgRequests = {};
      
      for (final requestDoc in allOrganizationsWithRequests.docs) {
        final requestData = requestDoc.data() as Map<String, dynamic>;
        final orgId = requestData['organizationId'] as String?;
        
        if (orgId != null) {
          orgRequests[orgId] ??= [];
          orgRequests[orgId]!.add(requestDoc);
        }
      }

      // Process each organization (only once per organization)
      for (final orgId in orgRequests.keys) {
        if (processedOrgIds.contains(orgId)) {
          print('⚠️ Skipping duplicate organization: $orgId');
          continue;
        }

        // Get organization details
        final orgDoc = await FirebaseFirestore.instance.collection('users').doc(orgId).get();
        if (!orgDoc.exists) continue;

        final orgData = orgDoc.data()!;
        final orgName = orgData['organizationName'] as String? ?? 'Unknown Organization';
        final orgEmail = orgData['email'] as String? ?? 'Unknown';

        // Get the earliest request for this organization (FIFO)
        final orgRequestsList = orgRequests[orgId]!;
        
        // Filter to only include requests for this specific title and category
        final matchingRequests = orgRequestsList.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['title'] == title && data['category'] == category;
        }).toList();
        
        if (matchingRequests.isEmpty) {
          print('⚠️ No matching requests for $orgId for $title in $category');
          continue;
        }
        
        matchingRequests.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['timestamp'] as Timestamp?;
          final bTime = bData['timestamp'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime); // Oldest first
        });

        final earliestRequest = matchingRequests.first;
        final requestData = earliestRequest.data() as Map<String, dynamic>;
        final quantity = requestData['quantity'] as int? ?? 0;
        final timestamp = requestData['timestamp'] as Timestamp?;
        final requestStatus = requestData['status'] as String? ?? 'pending';

        organizations.add({
          'id': orgId,
          'name': orgName,
          'email': orgEmail,
          'requestedQuantity': quantity,
          'timestamp': timestamp,
          'position': 0, // Will be calculated below
          'requestStatus': requestStatus, // Add status for display
        });

        processedOrgIds.add(orgId);
        print('✅ Added organization $orgName (ID: $orgId) for $title in $category (status: $requestStatus)');
      }

      // Sort by timestamp (FIFO)
      organizations.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime); // Oldest first
      });

      for (int i = 0; i < organizations.length; i++) {
        organizations[i]['position'] = i + 1;
      }

      print('🎯 Final priority order for $title in $category:');
      for (final org in organizations) {
        final position = org['position'] as int;
        final name = org['name'] as String;
        final status = org['requestStatus'] as String;
        final timestamp = org['timestamp'] as Timestamp?;
        final timeStr = timestamp?.toDate().toString() ?? 'No timestamp';
        print('  $position. $name (status: $status) - $timeStr');
      }

      return organizations;
    } catch (e) {
      print('❌ Error in _getMatchingOrganizationsForTitle: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Distribute Donations'),
          backgroundColor: Colors.deepPurple,
          bottom: TabBar(
            isScrollable: true,
            tabs: _categories.map((category) => Tab(text: category)).toList(),
            onTap: (index) {
              setState(() {
                _selectedCategory = _categories[index];
              });
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadCategoryData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Availability Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey.shade100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Donations by Category and Title:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _categoryTitleAvailability.entries.map((categoryEntry) {
                            // Calculate total for this category
                            final totalForCategory = categoryEntry.value.values.fold(0, (sum, quantity) => sum + quantity);
                            
                            return Wrap(
                              spacing: 4,
                              children: [
                                // Category total chip
                                Chip(
                                  label: Text('${categoryEntry.key}: TOTAL $totalForCategory'),
                                  backgroundColor: Colors.blue.shade100,
                                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                // Individual title chips
                                ...categoryEntry.value.entries.map((titleEntry) {
                                  return Chip(
                                    label: Text('${titleEntry.key} (${titleEntry.value})'),
                                    backgroundColor: titleEntry.value > 0 ? Colors.green.shade100 : Colors.red.shade100,
                                  );
                                }).toList(),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  
                  // Category Content
                  Expanded(
                    child: _selectedCategory == 'All'
                        ? _buildAllCategoriesView()
                        : _buildCategoryView(_selectedCategory),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAllCategoriesView() {
    final categoriesWithData = _categoryTitleAvailability.keys.where((cat) => cat != 'All').toList();
    
    if (categoriesWithData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No donations available for distribution',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categoriesWithData.length,
      itemBuilder: (context, index) {
        final category = categoriesWithData[index];
        return _buildCategoryCard(category);
      },
    );
  }

  Widget _buildCategoryView(String category) {
    final titles = _categoryTitleAvailability[category]?.keys.toList() ?? [];
    
    print('📋 Building category view for: $category with ${titles.length} titles: $titles');
    
    if (titles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No $category donations available',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: titles.length,
      itemBuilder: (context, index) {
        final title = titles[index];
        return _buildTitleCard(category, title);
      },
    );
  }

  Widget _buildCategoryCard(String category) {
    final titles = _categoryTitleAvailability[category]?.keys.toList() ?? [];
    final totalForCategory = _categoryTitleAvailability[category]?.values.fold(0, (sum, quantity) => sum + quantity) ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          category,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text('${titles.length} titles available • Total: $totalForCategory items'),
        children: titles.map((title) => _buildTitleCard(category, title)).toList(),
      ),
    );
  }

  Widget _buildTitleCard(String category, String title) {
    final availableQuantity = _categoryTitleAvailability[category]?[title] ?? 0;
    final key = '$category-$title';
    
    print('🎨 Building UI for title: $title in category: $category (available: $availableQuantity)');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category: $category',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Available: $availableQuantity items',
                        style: TextStyle(
                          color: availableQuantity > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Priority Order:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getMatchingOrganizationsForTitle(category, title),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('Loading matching organizations...');
                }

                final organizations = snapshot.data!;
                
                if (organizations.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No organizations have requested this specific title.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show priority order
                    ...organizations.map((org) {
                      final position = org['position'] as int;
                      final requestedQuantity = org['requestedQuantity'] as int;
                      final requestStatus = org['requestStatus'] as String;
                      final timestamp = org['timestamp'] as Timestamp?;
                      
                      // Format timestamp for debugging
                      String timeStr = 'No timestamp';
                      if (timestamp != null) {
                        timeStr = '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}';
                      }
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: position == 1 ? Colors.green.shade50 : Colors.grey.shade50,
                          border: Border.all(
                            color: position == 1 ? Colors.green : Colors.grey,
                            width: position == 1 ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: position == 1 ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$position',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${org['name']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '$requestedQuantity items - ${requestStatus.toUpperCase()} - $timeStr',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    
                    if (organizations.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '🎯 Will assign to: ${organizations.first['name']} (Priority #1)',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading || availableQuantity <= 0
                    ? null
                    : () async {
                        final organizations = await _getMatchingOrganizationsForTitle(category, title);
                        if (organizations.isNotEmpty) {
                          final firstOrg = organizations.first;
                          final orgId = firstOrg['id'] as String;
                          final orgName = firstOrg['name'] as String;
                          
                          _assignDonationToOrganization(
                            category,
                            title,
                            orgId,
                            orgName,
                          );
                        }
                      },
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.local_shipping),
                label: Text(_isLoading ? 'Assigning...' : 'Assign to Priority #1'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 