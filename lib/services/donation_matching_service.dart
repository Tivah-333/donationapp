import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class DonationMatchingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate distance between two coordinates in kilometers
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  /// Find organizations near a pickup station
  static Future<List<Map<String, dynamic>>> findOrganizationsNearPickupStation(
    String pickupStation,
    double maxDistance,
  ) async {
    try {
      final orgsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Organization')
          .where('status', isEqualTo: 'approved')
          .get();

      final organizations = <Map<String, dynamic>>[];

      for (final doc in orgsSnapshot.docs) {
        final orgData = doc.data();
        final orgLocation = _extractLocationString(orgData['location']);
        
        print('🏢 Organization ${orgData['organizationName']}: checking proximity to pickup station $pickupStation');
        
        // Include organizations with location data that are reasonably close to pickup station
        if (orgLocation != null) {
          final similarity = _calculateLocationSimilarity(pickupStation, orgLocation);
          print('📍 Location similarity: ${similarity.toStringAsFixed(2)} for ${orgData['organizationName']}');
          
          if (similarity >= 0.2) { // Lower threshold to 20% for more flexibility
            organizations.add({
              'id': doc.id,
              'name': orgData['organizationName'] ?? 'Unknown Organization',
              'email': orgData['email'] ?? '',
              'location': orgLocation,
              'distance': 1.0 - similarity, // Convert similarity to distance-like metric
              ...orgData,
            });
            print('✅ Added organization ${orgData['organizationName']} near pickup station (similarity: ${similarity.toStringAsFixed(2)})');
          }
        } else {
          // Include organizations without location data (they might be able to access pickup stations)
          print('⚠️ Organization ${orgData['organizationName']} has no location data, including for pickup consideration');
          organizations.add({
            'id': doc.id,
            'name': orgData['organizationName'] ?? 'Unknown Organization',
            'email': orgData['email'] ?? '',
            'location': 'Location to be detected',
            'distance': 999.0, // High distance for orgs without location
            ...orgData,
          });
        }
      }

      // Sort by distance (lower distance = higher similarity)
      organizations.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      
      return organizations;
    } catch (e) {
      print('Error finding organizations near pickup station: $e');
      return [];
    }
  }

  /// Find organizations in the same location as donor (for drop-off)
  static Future<List<Map<String, dynamic>>> findOrganizationsInSameLocation(
    String donorLocation,
  ) async {
    try {
      final orgsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Organization')
          .where('status', isEqualTo: 'approved')
          .get();

      final organizations = <Map<String, dynamic>>[];

      for (final doc in orgsSnapshot.docs) {
        final orgData = doc.data();
        final orgLocation = _extractLocationString(orgData['location']);
        
        print('🏢 Organization ${orgData['organizationName']}: location data = ${orgData['location']}, extracted = $orgLocation');
        
        // Include organizations with matching location OR organizations without location data
        // (they will get location when they make donation requests)
        if (orgLocation == null || _isSameLocation(donorLocation, orgLocation)) {
          organizations.add({
            'id': doc.id,
            'name': orgData['organizationName'] ?? 'Unknown Organization',
            'email': orgData['email'] ?? '',
            'location': orgLocation ?? 'Location to be detected',
            'distance': orgLocation == null ? 999.0 : 0.0, // Higher distance for orgs without location
            ...orgData,
          });
          print('✅ Added organization ${orgData['organizationName']} ${orgLocation == null ? '(no location yet)' : 'as matching location'}');
        }
      }

      print('🎯 Found ${organizations.length} organizations in same location as donor');
      return organizations;
    } catch (e) {
      print('Error finding organizations in same location: $e');
      return [];
    }
  }

  /// Check if two locations are the same (improved comparison)
  static bool _isSameLocation(String location1, String location2) {
    // Normalize locations for comparison
    final normalized1 = location1.toLowerCase().trim();
    final normalized2 = location2.toLowerCase().trim();
    
    // Check if they contain the same key terms
    final terms1 = normalized1.split(RegExp(r'[,\s]+'));
    final terms2 = normalized2.split(RegExp(r'[,\s]+'));
    
    // If they have common significant terms, consider them the same location
    final commonTerms = terms1.where((term) => 
      term.length > 2 && terms2.contains(term)
    ).length;
    
    return commonTerms >= 1; // At least one common significant term
  }

  /// Calculate similarity between two location strings
  static double _calculateLocationSimilarity(String location1, String location2) {
    // Normalize locations
    final normalized1 = location1.toLowerCase().trim();
    final normalized2 = location2.toLowerCase().trim();
    
    // Split into terms
    final terms1 = normalized1.split(RegExp(r'[,\s]+')).where((term) => term.length > 2).toSet();
    final terms2 = normalized2.split(RegExp(r'[,\s]+')).where((term) => term.length > 2).toSet();
    
    if (terms1.isEmpty || terms2.isEmpty) return 0.0;
    
    // Calculate Jaccard similarity
    final intersection = terms1.intersection(terms2).length;
    final union = terms1.union(terms2).length;
    
    return intersection / union;
  }

  /// Extract location string from various data formats (String, GeoPoint, Map)
  static String? _extractLocationString(dynamic locationData) {
    if (locationData == null) {
      return null;
    }
    
    if (locationData is String) {
      // Skip placeholder locations and empty strings
      if (locationData.contains('Location to be detected') || 
          locationData.isEmpty || 
          locationData.trim().isEmpty) {
        return null;
      }
      return locationData;
    }
    
    if (locationData is Map<String, dynamic>) {
      // Handle location stored as a map with address components
      final address = locationData['address'] as String?;
      final city = locationData['city'] as String?;
      final country = locationData['country'] as String?;
      
      if (address != null && address.isNotEmpty) {
        return address;
      }
      
      // Construct address from components
      final parts = <String>[];
      if (city != null && city.isNotEmpty) parts.add(city);
      if (country != null && country.isNotEmpty) parts.add(country);
      
      return parts.isNotEmpty ? parts.join(', ') : null;
    }
    
    // Handle GeoPoint - convert to a readable location string
    if (locationData.toString().contains('GeoPoint')) {
      print('⚠️ Found GeoPoint location data: $locationData');
      // For now, return null since we can't reverse geocode easily
      // Location will be set when organization makes donation requests
      return null;
    }
    
    print('⚠️ Unknown location data format: ${locationData.runtimeType} - $locationData');
    return null;
  }

  /// Get available donation quantity for a specific category
  static Future<int> getAvailableDonationQuantity(String category) async {
    try {
      // Get all donations for this category (including assigned ones)
      final allDonationsSnapshot = await _firestore
          .collection('donations')
          .get();

      int totalDonated = 0;
      int totalAssigned = 0;

      for (final doc in allDonationsSnapshot.docs) {
        final donationData = doc.data();
        final categorySummary = donationData['categorySummary'] as Map<String, dynamic>?;
        
        if (categorySummary != null && categorySummary.containsKey(category)) {
          final quantity = categorySummary[category] as int? ?? 0;
          totalDonated += quantity; // Count all donations regardless of status
          
          // Check if this donation was assigned (now shows as 'approved' to donors)
          final status = donationData['status'] as String? ?? 'pending';
          if (status == 'approved' && donationData['assignedTo'] != null) {
            // Get the actual requested quantity from the donation request
            final assignedTo = donationData['assignedTo'] as String?;
            if (assignedTo != null) {
              final requestsSnapshot = await _firestore
                  .collection('donation_requests')
                  .where('organizationId', isEqualTo: assignedTo)
                  .where('category', isEqualTo: category)
                  .where('status', isEqualTo: 'assigned')
                  .get();
              
              for (final requestDoc in requestsSnapshot.docs) {
                final requestData = requestDoc.data();
                final requestedQuantity = requestData['quantity'] as int? ?? 0;
                totalAssigned += requestedQuantity;
              }
            }
          }
        }
      }

      final available = totalDonated - totalAssigned;
      print('📊 Available quantity for $category: $totalDonated (total donated) - $totalAssigned (assigned) = $available');
      return available > 0 ? available : 0;
    } catch (e) {
      print('Error getting available donation quantity: $e');
      return 0;
    }
  }

  /// Get available donations by category with location filtering
  static Future<Map<String, int>> getAvailableDonationsByCategory() async {
    try {
      final donationsSnapshot = await _firestore
          .collection('donations')
          .where('status', whereIn: ['pending', 'approved'])
          .get();

      final categoryQuantities = <String, int>{};

      for (final doc in donationsSnapshot.docs) {
        final donationData = doc.data();
        final categorySummary = donationData['categorySummary'] as Map<String, dynamic>?;
        
        if (categorySummary != null) {
          for (final entry in categorySummary.entries) {
            final category = entry.key as String;
            final quantity = entry.value as int? ?? 0;
            categoryQuantities[category] = (categoryQuantities[category] ?? 0) + quantity;
          }
        }
      }

      return categoryQuantities;
    } catch (e) {
      print('Error getting available donations by category: $e');
      return {};
    }
  }

  /// Check if requested quantity is available
  static Future<bool> isQuantityAvailable(String category, int requestedQuantity) async {
    final availableQuantity = await getAvailableDonationQuantity(category);
    return availableQuantity >= requestedQuantity;
  }

  /// Get the maximum quantity that can be provided for a category
  static Future<int> getMaxAvailableQuantity(String category) async {
    return await getAvailableDonationQuantity(category);
  }

  /// Check if an organization has matching donation requests for given categories
  static Future<bool> hasMatchingRequests(String organizationId, List<String> categories) async {
    try {
      print('🔍 Checking if organization $organizationId has matching requests for categories: $categories');
      
      final requestsSnapshot = await _firestore
          .collection('donation_requests')
          .where('organizationId', isEqualTo: organizationId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      print('📋 Found ${requestsSnapshot.docs.length} pending requests for organization $organizationId');
      
      for (final requestDoc in requestsSnapshot.docs) {
        final requestData = requestDoc.data();
        final requestCategory = requestData['category'] as String?;
        
        if (requestCategory != null && categories.contains(requestCategory)) {
          print('✅ Found matching request: $requestCategory');
          return true;
        }
      }
      
      print('❌ No matching requests found');
      return false;
    } catch (e) {
      print('Error checking matching requests: $e');
      return false;
    }
  }

  /// Check if an organization has any pending requests for a specific category
  static Future<bool> hasOrganizationRequestsForCategory(
    String organizationId,
    String category,
  ) async {
    try {
      final requestsSnapshot = await _firestore
          .collection('donation_requests')
          .where('organizationId', isEqualTo: organizationId)
          .where('category', isEqualTo: category)
          .where('status', isEqualTo: 'pending')
          .get();
      
      final hasRequests = requestsSnapshot.docs.isNotEmpty;
      print('🔍 Organization $organizationId has requests for $category: $hasRequests (${requestsSnapshot.docs.length} requests)');
      
      return hasRequests;
    } catch (e) {
      print('Error checking organization requests for category: $e');
      return false;
    }
  }

  /// Get all pending requests for a category with organization details
  static Future<List<Map<String, dynamic>>> getPendingRequestsForCategory(String category) async {
    try {
      final requestsSnapshot = await _firestore
          .collection('donation_requests')
          .where('category', isEqualTo: category)
          .where('status', isEqualTo: 'pending')
          .get();
      
      final requests = <Map<String, dynamic>>[];
      
      for (final doc in requestsSnapshot.docs) {
        final data = doc.data();
        requests.add({
          'id': doc.id,
          'organizationId': data['organizationId'],
          'title': data['title'],
          'timestamp': data['timestamp'],
          ...data,
        });
      }
      
      // Sort by timestamp (oldest first)
      requests.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime); // Oldest first
      });
      
      print('📋 Found ${requests.length} pending requests for $category');
      for (int i = 0; i < requests.length; i++) {
        final request = requests[i];
        print('  ${i + 1}. ${request['organizationId']} - "${request['title']}" (${request['timestamp']})');
      }
      
      return requests;
    } catch (e) {
      print('Error getting pending requests for category: $e');
      return [];
    }
  }

  /// Get organizations with their FIFO positions for specific categories
  static Future<List<Map<String, dynamic>>> getOrganizationsWithFIFOPositions(
    List<String> categories,
    String deliveryOption,
    String? pickupStation,
    String? donorLocation,
  ) async {
    try {
      // First, get all organizations that match location criteria
      List<Map<String, dynamic>> locationMatchedOrgs;
      
      if (deliveryOption == 'Pickup' && pickupStation != null) {
        locationMatchedOrgs = await findOrganizationsNearPickupStation(pickupStation, 50.0);
      } else if (deliveryOption == 'Drop-off' && donorLocation != null) {
        locationMatchedOrgs = await findOrganizationsInSameLocation(donorLocation);
      } else {
        // Fallback: get all approved organizations
        final orgsSnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'Organization')
            .where('status', isEqualTo: 'approved')
            .get();

        locationMatchedOrgs = orgsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['organizationName'] ?? 'Unknown Organization',
            'email': data['email'] ?? '',
            'location': data['location'] ?? 'Unknown location',
            'distance': 0.0,
            ...data,
          };
        }).toList();
      }

      // Now get ALL organizations that have requests for ANY of the donation categories
      final orgsWithRequests = <Map<String, dynamic>>[];
      
      for (final org in locationMatchedOrgs) {
        final orgId = org['id'] as String;
        
        // Check each category and collect ALL matching requests
        for (final category in categories) {
          print('🔍 Checking if organization ${org['name']} has requests for $category...');
          final requestsSnapshot = await _firestore
              .collection('donation_requests')
              .where('organizationId', isEqualTo: orgId)
              .where('category', isEqualTo: category)
              .where('status', isEqualTo: 'pending')
              .get();
          
          print('📋 Found ${requestsSnapshot.docs.length} pending requests for $category from ${org['name']}');
          
          if (requestsSnapshot.docs.isNotEmpty) {
            // Get all requests for this category to determine position
            final allCategoryRequests = await _firestore
                .collection('donation_requests')
                .where('category', isEqualTo: category)
                .where('status', isEqualTo: 'pending')
                .get();
            
            // Sort by timestamp (oldest first for FIFO)
            final sortedRequests = allCategoryRequests.docs.toList()
              ..sort((a, b) {
                final aTime = a.data()['timestamp'] as Timestamp?;
                final bTime = b.data()['timestamp'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return aTime.compareTo(bTime); // Oldest first
              });
            
            // Find position of this organization in the queue
            int? position;
            String? matchingTitle;
            for (int i = 0; i < sortedRequests.length; i++) {
              if (sortedRequests[i].data()['organizationId'] == orgId) {
                position = i + 1; // 1-based position
                matchingTitle = sortedRequests[i].data()['title'] as String?;
                break;
              }
            }
            
            // Add this organization for this category
            final enhancedOrg = Map<String, dynamic>.from(org);
            enhancedOrg['position'] = position;
            enhancedOrg['hasMatchingRequests'] = true;
            enhancedOrg['matchingCategory'] = category;
            enhancedOrg['matchingTitle'] = matchingTitle;
            enhancedOrg['orgId'] = orgId; // Add unique identifier
            enhancedOrg['displayName'] = '${org['name']} [$category]'; // Add category to display name
            orgsWithRequests.add(enhancedOrg);
            
            print('✅ Organization ${org['name']} has request for $category (position: $position)');
          }
        }
        
        // If no matching requests found for specific categories, check for ANY pending requests
        if (!orgsWithRequests.any((orgWithReq) => orgWithReq['orgId'] == orgId)) {
          final anyRequestsSnapshot = await _firestore
              .collection('donation_requests')
              .where('organizationId', isEqualTo: orgId)
              .where('status', isEqualTo: 'pending')
              .get();
          
          print('📋 Organization ${org['name']} has ${anyRequestsSnapshot.docs.length} total pending requests');
          
          if (anyRequestsSnapshot.docs.isNotEmpty) {
            // Get the first request to show what they're waiting for
            final firstRequest = anyRequestsSnapshot.docs.first;
            final requestCategory = firstRequest.data()['category'] as String?;
            final requestTitle = firstRequest.data()['title'] as String?;
            
            final enhancedOrg = Map<String, dynamic>.from(org);
            enhancedOrg['position'] = null; // No position since it's not for the specific category
            enhancedOrg['hasMatchingRequests'] = false; // Not matching the donation categories
            enhancedOrg['matchingCategory'] = requestCategory;
            enhancedOrg['matchingTitle'] = requestTitle;
            enhancedOrg['waitingFor'] = requestCategory; // Show what they're waiting for
            enhancedOrg['orgId'] = orgId;
            enhancedOrg['displayName'] = '${org['name']} [waiting for $requestCategory]';
            orgsWithRequests.add(enhancedOrg);
            
            print('⏳ Organization ${org['name']} is waiting for $requestCategory donations');
          }
        }
      }
      
      // Sort by position (1st come, 1st served) and then by organization name
      orgsWithRequests.sort((a, b) {
        final posA = a['position'] as int? ?? 999;
        final posB = b['position'] as int? ?? 999;
        if (posA != posB) {
          return posA.compareTo(posB);
        }
        // If same position, sort by organization name
        final nameA = a['name'] as String? ?? '';
        final nameB = b['name'] as String? ?? '';
        return nameA.compareTo(nameB);
      });
      
      print('🎯 Found ${orgsWithRequests.length} organizations with matching requests');
      for (final org in orgsWithRequests) {
        print('  - ${org['name']} (Position: ${org['position']}, Category: ${org['matchingCategory']}, Title: ${org['matchingTitle']})');
      }
      
      return orgsWithRequests;
    } catch (e) {
      print('Error getting organizations with FIFO positions: $e');
      return [];
    }
  }

  /// Check if organization is first in line for the given category and title
  static Future<bool> isOrganizationFirstInLine(
    String organizationId, 
    String category, 
    String? donationTitle
  ) async {
    try {
      // First, check if this organization has a request for this category
      final orgRequestsSnapshot = await _firestore
          .collection('donation_requests')
          .where('organizationId', isEqualTo: organizationId)
          .where('category', isEqualTo: category)
          .where('status', isEqualTo: 'pending')
          .get();

      if (orgRequestsSnapshot.docs.isEmpty) {
        print('❌ Organization $organizationId has no pending requests for $category');
        return false;
      }

      // Get all pending requests for this category
      final allRequestsSnapshot = await _firestore
          .collection('donation_requests')
          .where('category', isEqualTo: category)
          .where('status', isEqualTo: 'pending')
          .get();

      if (allRequestsSnapshot.docs.isEmpty) {
        return true; // No requests, so this organization can be assigned
      }

      // Sort by timestamp in memory (oldest first for FIFO)
      final sortedRequests = allRequestsSnapshot.docs.toList()
        ..sort((a, b) {
          final aTime = a.data()['timestamp'] as Timestamp?;
          final bTime = b.data()['timestamp'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime); // Oldest first
        });

      // Find the first organization in line
      final firstRequest = sortedRequests.first;
      final firstOrgId = firstRequest.data()['organizationId'] as String?;
      final firstRequestTitle = firstRequest.data()['title'] as String?;

      // Check if the selected organization is the first one
      if (firstOrgId != organizationId) {
        print('❌ Organization $organizationId is not first in line. First is: $firstOrgId');
        return false;
      }

      // Only check title matching if both titles are provided and not empty
      if (donationTitle != null && firstRequestTitle != null && 
          donationTitle.isNotEmpty && firstRequestTitle.isNotEmpty) {
        final titleSimilarity = _calculateTitleSimilarity(donationTitle, firstRequestTitle);
        if (titleSimilarity < 0.3) { // Lower threshold to 30% for more flexibility
          print('⚠️ Title similarity low: donation="$donationTitle" vs request="$firstRequestTitle" (similarity: ${titleSimilarity.toStringAsFixed(2)})');
          // Don't block assignment for title mismatch, just log it
        } else {
          print('✅ Title match: donation="$donationTitle" vs request="$firstRequestTitle" (similarity: ${titleSimilarity.toStringAsFixed(2)})');
        }
      }

      print('✅ Organization $organizationId is first in line for $category');
      return true;
    } catch (e) {
      print('Error checking FIFO order: $e');
      return false;
    }
  }

  /// Check if organization is first in line for a specific title within a category
  static Future<bool> isOrganizationFirstInLineForTitle(
    String organizationId, 
    String category, 
    String title
  ) async {
    try {
      // Check if this organization has a request for this specific title and category
      final orgRequestsSnapshot = await _firestore
          .collection('donation_requests')
          .where('organizationId', isEqualTo: organizationId)
          .where('category', isEqualTo: category)
          .where('title', isEqualTo: title)
          .where('status', isEqualTo: 'pending')
          .get();

      if (orgRequestsSnapshot.docs.isEmpty) {
        print('❌ Organization $organizationId has no pending requests for $title in $category');
        return false;
      }

      // Get all pending requests for this specific title and category
      final allRequestsSnapshot = await _firestore
          .collection('donation_requests')
          .where('category', isEqualTo: category)
          .where('title', isEqualTo: title)
          .where('status', isEqualTo: 'pending')
          .get();

      if (allRequestsSnapshot.docs.isEmpty) {
        return true; // No requests, so this organization can be assigned
      }

      // Sort by timestamp in memory (oldest first for FIFO)
      final sortedRequests = allRequestsSnapshot.docs.toList()
        ..sort((a, b) {
          final aTime = a.data()['timestamp'] as Timestamp?;
          final bTime = b.data()['timestamp'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime); // Oldest first
        });

      // Find the first organization in line
      final firstRequest = sortedRequests.first;
      final firstOrgId = firstRequest.data()['organizationId'] as String?;

      // Check if the selected organization is the first one
      if (firstOrgId != organizationId) {
        print('❌ Organization $organizationId is not first in line for $title in $category. First is: $firstOrgId');
        return false;
      }

      print('✅ Organization $organizationId is first in line for $title in $category');
      return true;
    } catch (e) {
      print('Error checking FIFO order for title: $e');
      return false;
    }
  }

  /// Calculate title similarity between donation and request
  static double _calculateTitleSimilarity(String title1, String title2) {
    // Normalize text
    final normalized1 = title1.toLowerCase().trim();
    final normalized2 = title2.toLowerCase().trim();
    
    // If they're exactly the same, return 1.0
    if (normalized1 == normalized2) return 1.0;
    
    // Check if one contains the other
    if (normalized1.contains(normalized2) || normalized2.contains(normalized1)) {
      return 0.9; // High similarity for partial matches
    }
    
    // Handle plural/singular forms
    final singular1 = normalized1.endsWith('s') ? normalized1.substring(0, normalized1.length - 1) : normalized1;
    final singular2 = normalized2.endsWith('s') ? normalized2.substring(0, normalized2.length - 1) : normalized2;
    
    if (singular1 == singular2 || singular1.contains(singular2) || singular2.contains(singular1)) {
      return 0.8; // Good similarity for singular/plural matches
    }
    
    // Handle common variations and abbreviations
    final variations1 = [normalized1, singular1, normalized1.replaceAll(' ', ''), singular1.replaceAll(' ', '')];
    final variations2 = [normalized2, singular2, normalized2.replaceAll(' ', ''), singular2.replaceAll(' ', '')];
    
    for (final var1 in variations1) {
      for (final var2 in variations2) {
        if (var1 == var2 || var1.contains(var2) || var2.contains(var1)) {
          return 0.7; // Good similarity for variations
        }
      }
    }
    
    // Split comma-separated items and check each one
    final items1 = normalized1.split(',').map((item) => item.trim()).toList();
    final items2 = normalized2.split(',').map((item) => item.trim()).toList();
    
    // Check if any item from title1 matches any item from title2
    for (final item1 in items1) {
      for (final item2 in items2) {
        if (item1 == item2) return 1.0; // Exact match
        if (item1.contains(item2) || item2.contains(item1)) return 0.8; // Partial match
        
        // Check singular/plural for each item
        final itemSingular1 = item1.endsWith('s') ? item1.substring(0, item1.length - 1) : item1;
        final itemSingular2 = item2.endsWith('s') ? item2.substring(0, item2.length - 1) : item2;
        
        if (itemSingular1 == itemSingular2 || itemSingular1.contains(itemSingular2) || itemSingular2.contains(itemSingular1)) {
          return 0.7; // Good similarity for singular/plural matches
        }
      }
    }
    
    // Split into words and remove common words
    final commonWords = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by'};
    final words1 = normalized1.split(RegExp(r'[,\s]+'))
        .where((word) => word.length > 1 && !commonWords.contains(word))
        .toSet();
    final words2 = normalized2.split(RegExp(r'[,\s]+'))
        .where((word) => word.length > 1 && !commonWords.contains(word))
        .toSet();
    
    if (words1.isEmpty || words2.isEmpty) return 0.0;
    
    // Calculate Jaccard similarity
    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    
    final similarity = intersection / union;
    
    // Boost similarity for exact word matches
    if (intersection > 0) {
      return similarity + 0.6; // Add boost for any shared words
    }
    
    return similarity;
  }

  /// Find organizations that can receive donations based on delivery option and location
  static Future<List<Map<String, dynamic>>> findMatchingOrganizationsForDonation(
    String deliveryOption,
    String? pickupStation,
    String? donorLocation,
    List<String> categories,
  ) async {
    try {
      List<Map<String, dynamic>> matchingOrgs = [];

      if (deliveryOption == 'Pickup' && pickupStation != null) {
        // For pickup: find organizations near the pickup station
        matchingOrgs = await findOrganizationsNearPickupStation(pickupStation, 50.0);
      } else if (deliveryOption == 'Drop-off' && donorLocation != null) {
        // For drop-off: find organizations in the same location as donor
        matchingOrgs = await findOrganizationsInSameLocation(donorLocation);
      } else {
        // Fallback: get all approved organizations
        final orgsSnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'Organization')
            .where('status', isEqualTo: 'approved')
            .get();

        matchingOrgs = orgsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['organizationName'] ?? 'Unknown Organization',
            'email': data['email'] ?? '',
            'location': data['location'] ?? 'Unknown location',
            'distance': 0.0,
            ...data,
          };
        }).toList();
      }

      // Filter organizations that have requested categories (if any)
      if (categories.isNotEmpty) {
        matchingOrgs = matchingOrgs.where((org) {
          // For now, assume all organizations can handle all categories
          // In a real app, you might want to track which categories each organization handles
          return true;
        }).toList();
      }

      return matchingOrgs;
    } catch (e) {
      print('Error finding matching organizations: $e');
      return [];
    }
  }

  /// Match donation request to available donations
  static Future<List<Map<String, dynamic>>> matchDonationRequest(
    String category,
    int requestedQuantity,
    String deliveryOption,
    String? pickupStation,
    String? donorLocation,
  ) async {
    try {
      List<Map<String, dynamic>> matchedDonations = [];
      int remainingQuantity = requestedQuantity;

      // Get approved donations with matching category
      final donationsQuery = _firestore
          .collection('donations')
          .where('status', isEqualTo: 'approved');

      final donationsSnapshot = await donationsQuery.get();

      for (final donationDoc in donationsSnapshot.docs) {
        if (remainingQuantity <= 0) break;

        final itemsSnapshot = await donationDoc.reference.collection('items').get();
        
        for (final itemDoc in itemsSnapshot.docs) {
          if (remainingQuantity <= 0) break;

          final itemData = itemDoc.data();
          if (itemData['category'] == category) {
            final availableQuantity = itemData['quantity'] as int? ?? 0;
            final quantityToUse = availableQuantity > remainingQuantity 
                ? remainingQuantity 
                : availableQuantity;

            matchedDonations.add({
              'donationId': donationDoc.id,
              'itemId': itemDoc.id,
              'category': category,
              'quantity': quantityToUse,
              'donorEmail': donationDoc.data()['donorEmail'],
              'location': donationDoc.data()['location'],
              'deliveryOption': donationDoc.data()['deliveryOption'],
              'pickupStation': donationDoc.data()['pickupStation'],
            });

            remainingQuantity -= quantityToUse;
          }
        }
      }

      return matchedDonations;
    } catch (e) {
      print('Error matching donation request: $e');
      return [];
    }
  }
} 