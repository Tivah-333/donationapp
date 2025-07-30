import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'fcm_service.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send notification to admin
  static Future<void> sendAdminNotification({
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Store in Firestore
      await _firestore.collection('admin_notifications').add({
        'type': type,
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'starred': false,
        ...?additionalData,
      });

      // Send push notification to all admins
      await _sendPushNotificationToTopic(
        topic: 'admins',
        title: title,
        message: message,
        data: {
          'type': type,
          ...?additionalData,
        },
      );
    } catch (e) {
      print('Error sending admin notification: $e');
    }
  }

  /// Send notification to organization
  static Future<void> sendOrganizationNotification({
    required String organizationId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Store in Firestore
      await _firestore.collection('organization_notifications').add({
        'organizationId': organizationId,
        'type': type,
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        ...?additionalData,
      });

      // Send push notification
      await _sendPushNotification(
        userId: organizationId,
        title: title,
        message: message,
        data: {
          'type': type,
          ...?additionalData,
        },
      );
    } catch (e) {
      print('Error sending organization notification: $e');
    }
  }

  /// Send notification to donor
  static Future<void> sendDonorNotification({
    required String donorId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Store in Firestore
      await _firestore.collection('donor_notifications').add({
        'donorId': donorId,
        'type': type,
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        ...?additionalData,
      });

      // Send push notification
      await _sendPushNotification(
        userId: donorId,
        title: title,
        message: message,
        data: {
          'type': type,
          ...?additionalData,
        },
      );
    } catch (e) {
      print('Error sending donor notification: $e');
    }
  }

  /// Send donation status update notification
  static Future<void> sendDonationStatusNotification({
    required String donationId,
    required String status,
    required String recipientId,
    required String recipientType,
    String? donorEmail,
    String? organizationName,
    String? donationTitle,
    String? donationCategory,
    String? deliveryMethod,
    String? pickupStation,
    String? donorLocation,
  }) async {
    try {
      String message;
      String title;
      
      switch (status) {
        case 'approved':
          title = 'Donation Assigned';
          if (organizationName != null && donationTitle != null && donationCategory != null) {
            message = 'Your donation "$donationTitle" ($donationCategory) has been assigned to $organizationName';
            if (deliveryMethod != null) {
              message += '. Delivery method: $deliveryMethod';
              if (deliveryMethod == 'Pickup' && pickupStation != null) {
                message += ' - Pickup from: $pickupStation';
              } else if (deliveryMethod == 'Drop-off' && donorLocation != null) {
                message += ' - Drop-off at: $donorLocation';
              }
            }
          } else {
            message = organizationName != null 
                ? 'Your donation has been approved and assigned to $organizationName'
                : 'Your donation has been approved and assigned to an organization';
          }
          break;
        case 'delivered':
          title = 'Donation Delivered';
          message = 'Your donation has been delivered successfully';
          break;
        case 'rejected':
          title = 'Donation Request Rejected';
          message = 'Your donation request has been rejected';
          break;
        case 'picked_up':
          title = 'Donation Picked Up';
          message = 'Your donation has been picked up';
          break;
        case 'received':
          title = 'Donation Received';
          message = 'Your donation has been received by the organization';
          break;
        case 'not_received':
          title = 'Delivery Issue';
          message = 'There was an issue with your donation delivery';
          break;
        default:
          title = 'Donation Status Update';
          message = 'Your donation status has been updated to: $status';
      }

      if (recipientType == 'donor') {
        await sendDonorNotification(
          donorId: recipientId,
          type: 'donation_status',
          title: title,
          message: message,
          additionalData: {
            'donationId': donationId,
            'status': status,
            'organizationName': organizationName,
            'donationTitle': donationTitle,
            'donationCategory': donationCategory,
            'deliveryMethod': deliveryMethod,
            'pickupStation': pickupStation,
            'donorLocation': donorLocation,
          },
        );
      } else if (recipientType == 'organization') {
        await sendOrganizationNotification(
          organizationId: recipientId,
          type: 'donation_status',
          title: title,
          message: message,
          additionalData: {
            'donationId': donationId,
            'status': status,
            'donationTitle': donationTitle,
            'donationCategory': donationCategory,
            'deliveryMethod': deliveryMethod,
            'pickupStation': pickupStation,
            'donorLocation': donorLocation,
          },
        );
      }
    } catch (e) {
      print('Error sending donation status notification: $e');
    }
  }

  /// Send donation assigned notification to organization
  static Future<void> sendDonationAssignedNotification({
    required String organizationId,
    required String donationId,
    required List<String> categories,
    String? deliveryMethod,
    String? pickupStation,
    String? donorLocation,
    String? donationTitle,
    String? donationCategory,
  }) async {
    try {
      String message = 'You have been assigned a donation with categories: ${categories.join(', ')}';
      
      if (deliveryMethod != null) {
        message += '\n\nDelivery Method: $deliveryMethod';
        if (deliveryMethod == 'Pickup' && pickupStation != null) {
          message += '\nPickup Station: $pickupStation';
        } else if (deliveryMethod == 'Drop-off' && donorLocation != null) {
          message += '\nDonor Location: $donorLocation';
        }
      }
      
      if (donationTitle != null && donationCategory != null) {
        message += '\n\nDonation: $donationTitle ($donationCategory)';
      }
      
      message += '\n\nPlease review this assignment in your donation requests and approve or reject based on the delivery method.';

      await sendOrganizationNotification(
        organizationId: organizationId,
        type: 'donation_assigned',
        title: 'New Donation Assignment - Review Required',
        message: message,
        additionalData: {
          'donationId': donationId,
          'categories': categories,
          'deliveryMethod': deliveryMethod,
          'pickupStation': pickupStation,
          'donorLocation': donorLocation,
          'donationTitle': donationTitle,
          'donationCategory': donationCategory,
        },
      );
    } catch (e) {
      print('Error sending donation assigned notification: $e');
    }
  }

  /// Send donation request status notification to organization
  static Future<void> sendDonationRequestStatusNotification({
    required String organizationId,
    required String organizationEmail,
    required String status,
    required String requestTitle,
    required String requestCategory,
  }) async {
    try {
      await sendOrganizationNotification(
        organizationId: organizationId,
        type: 'request_status',
        title: 'Donation Request Status Update',
        message: 'Your request for $requestTitle ($requestCategory) has been $status.',
        additionalData: {
          'status': status,
          'title': requestTitle,
          'category': requestCategory,
        },
      );
    } catch (e) {
      print('Error sending donation request status notification: $e');
    }
  }

  /// Send delivery method notification to organization
  static Future<void> sendDeliveryMethodNotification({
    required String organizationId,
    required String donationId,
    required String deliveryMethod,
    String? pickupStation,
    String? donorLocation,
    required String category,
    required String title,
  }) async {
    try {
      String message = 'You have been assigned $title ($category). ';
      
      if (deliveryMethod == 'Pickup' && pickupStation != null) {
        message += 'Please pick up from: $pickupStation';
      } else if (deliveryMethod == 'Drop-off' && donorLocation != null) {
        message += 'Donation will be dropped off at: $donorLocation';
      } else {
        message += 'Delivery method: $deliveryMethod';
      }

      await sendOrganizationNotification(
        organizationId: organizationId,
        type: 'delivery_method',
        title: 'Donation Assignment - Delivery Method',
        message: message,
        additionalData: {
          'donationId': donationId,
          'deliveryMethod': deliveryMethod,
          'pickupStation': pickupStation,
          'donorLocation': donorLocation,
          'category': category,
          'title': title,
        },
      );
    } catch (e) {
      print('Error sending delivery method notification: $e');
    }
  }

  /// Send donor issue report notification
  static Future<void> sendDonorIssueReportNotification({
    required String donorId,
    required String donorEmail,
    required String issue,
    required String description,
    String? problemId,
  }) async {
    try {
      // Send to admin
      await sendAdminNotification(
        type: 'issue_report',
        title: 'New Issue Report from Donor',
        message: 'Donor $donorEmail has reported a problem: $description',
        additionalData: {
          'donorId': donorId,
          'donorEmail': donorEmail,
          'issue': issue,
          'description': description,
          'reportType': 'donor',
          'problemId': problemId,
          'senderEmail': donorEmail,
          'status': 'unresolved',
        },
      );
    } catch (e) {
      print('Error sending donor issue report notification: $e');
    }
  }

  /// Send organization issue report notification
  static Future<void> sendOrgIssueReportNotification({
    required String organizationId,
    required String organizationEmail,
    required String issue,
    required String description,
    String? problemId,
  }) async {
    try {
      // Send to admin
      await sendAdminNotification(
        type: 'issue_report',
        title: 'New Issue Report from Organization',
        message: 'Organization $organizationEmail has reported a problem: $description',
        additionalData: {
          'organizationId': organizationId,
          'organizationEmail': organizationEmail,
          'issue': issue,
          'description': description,
          'reportType': 'organization',
          'problemId': problemId,
          'senderEmail': organizationEmail,
          'status': 'unresolved',
        },
      );
    } catch (e) {
      print('Error sending organization issue report notification: $e');
    }
  }

  /// Send donor support notification
  static Future<void> sendDonorSupportNotification({
    required String donorId,
    required String donorEmail,
    required String message,
  }) async {
    try {
      // Send to admin
      await sendAdminNotification(
        type: 'support_request',
        title: 'Donor Support Request',
        message: 'Donor $donorEmail needs support: $message',
        additionalData: {
          'donorId': donorId,
          'donorEmail': donorEmail,
          'supportMessage': message,
          'requestType': 'donor',
        },
      );
    } catch (e) {
      print('Error sending donor support notification: $e');
    }
  }

  /// Send organization support notification
  static Future<void> sendOrgSupportNotification({
    required String organizationId,
    required String organizationEmail,
    required String message,
  }) async {
    try {
      // Send to admin
      await sendAdminNotification(
        type: 'support_request',
        title: 'Organization Support Request',
        message: 'Organization $organizationEmail needs support: $message',
        additionalData: {
          'organizationId': organizationId,
          'organizationEmail': organizationEmail,
          'supportMessage': message,
          'requestType': 'organization',
        },
      );
    } catch (e) {
      print('Error sending organization support notification: $e');
    }
  }

  /// Send organization approval notification
  static Future<void> sendOrganizationApprovalNotification({
    required String organizationId,
    required String status,
  }) async {
    try {
      final title = status == 'approved' 
          ? 'Organization Approved' 
          : 'Organization Status Update';
      
      final message = status == 'approved'
          ? 'Congratulations! Your organization has been approved. You can now log in and start using the app.'
          : 'Your organization status has been updated to: $status';

      await sendOrganizationNotification(
        organizationId: organizationId,
        type: 'organization_approval',
        title: title,
        message: message,
        additionalData: {
          'status': status,
        },
      );
    } catch (e) {
      print('Error sending organization approval notification: $e');
    }
  }



  /// Mark notification as read
  static Future<void> markNotificationAsRead({
    required String collection,
    required String notificationId,
  }) async {
    try {
      await _firestore
          .collection(collection)
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Get unread notification count for current user
  static Future<int> getUnreadNotificationCount({
    required String collection,
    String? userId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 0;

      final query = _firestore
          .collection(collection)
          .where('read', isEqualTo: false);

      // Add user-specific filter if needed
      if (userId != null) {
        if (collection == 'donor_notifications') {
          query.where('donorId', isEqualTo: userId);
        } else if (collection == 'organization_notifications') {
          query.where('organizationId', isEqualTo: userId);
        }
      }

      final snapshot = await query.get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread notification count: $e');
      return 0;
    }
  }

  /// Delete notification
  static Future<void> deleteNotification({
    required String collection,
    required String notificationId,
  }) async {
    try {
      await _firestore
          .collection(collection)
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Get notifications for current user
  static Stream<QuerySnapshot> getNotificationsStream({
    required String collection,
    String? userId,
  }) {
    try {
      Query query = _firestore
          .collection(collection)
          .orderBy('timestamp', descending: true);

      // Add user-specific filter if needed
      if (userId != null) {
        if (collection == 'donor_notifications') {
          query = query.where('donorId', isEqualTo: userId);
        } else if (collection == 'organization_notifications') {
          query = query.where('organizationId', isEqualTo: userId);
        }
      }

      return query.snapshots();
    } catch (e) {
      print('Error getting notifications stream: $e');
      return const Stream.empty();
    }
  }

  /// Send donation request denial notification when titles don't match
  static Future<void> sendRequestDenialNotification({
    required String organizationId,
    required String organizationEmail,
    required String requestedTitle,
    required String category,
    required String availableTitle,
  }) async {
    try {
      final message = 'Your request for "$requestedTitle" ($category) could not be fulfilled because the available donation "$availableTitle" does not match your request. Please check for other available donations or update your request.';

      await sendOrganizationNotification(
        organizationId: organizationId,
        type: 'request_denial',
        title: 'Request Not Fulfilled',
        message: message,
        additionalData: {
          'requestedTitle': requestedTitle,
          'category': category,
          'availableTitle': availableTitle,
          'reason': 'title_mismatch',
        },
      );
    } catch (e) {
      print('Error sending request denial notification: $e');
    }
  }

  /// Send donation request denial notification when quantity is insufficient
  static Future<void> sendInsufficientQuantityNotification({
    required String organizationId,
    required String organizationEmail,
    required String title,
    required String category,
    required int requestedQuantity,
    required int availableQuantity,
  }) async {
    try {
      final message = 'Your request for "$title" ($category) could not be fulfilled. Requested: $requestedQuantity, Available: $availableQuantity. Please check for other available donations or reduce your request quantity.';

      await sendOrganizationNotification(
        organizationId: organizationId,
        type: 'request_denial',
        title: 'Insufficient Quantity',
        message: message,
        additionalData: {
          'title': title,
          'category': category,
          'requestedQuantity': requestedQuantity,
          'availableQuantity': availableQuantity,
          'reason': 'insufficient_quantity',
        },
      );
    } catch (e) {
      print('Error sending insufficient quantity notification: $e');
    }
  }

  /// Send drop-off assignment notification to donor (when organization is far)
  static Future<void> sendDropoffAssignmentNotification({
    required String donorId,
    required String organizationName,
    required String organizationLocation,
    required String donorLocation,
    required String donationId,
    required String category,
    required String title,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://your-firebase-function-url/api/notifications/dropoff-assignment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: jsonEncode({
          'donorId': donorId,
          'organizationName': organizationName,
          'organizationLocation': organizationLocation,
          'donorLocation': donorLocation,
          'donationId': donationId,
          'category': category,
          'title': title,
        }),
      );
      
      if (response.statusCode == 200) {
        print('Dropoff assignment notification sent successfully');
      } else {
        print('Failed to send dropoff assignment notification: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending dropoff assignment notification: $e');
    }
  }

  /// Send support response notification to donor
  static Future<void> sendSupportResponseNotification({
    required String donorId,
    required String response,
    required String adminName,
  }) async {
    try {
      final responseResult = await http.post(
        Uri.parse('https://your-firebase-function-url/api/notifications/support-response'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: jsonEncode({
          'donorId': donorId,
          'response': response,
          'adminName': adminName,
        }),
      );
      
      if (responseResult.statusCode == 200) {
        print('Support response notification sent successfully');
      } else {
        print('Failed to send support response notification: ${responseResult.statusCode}');
      }
    } catch (e) {
      print('Error sending support response notification: $e');
    }
  }

  /// Send problem report response notification to donor
  static Future<void> sendProblemResponseNotification({
    required String donorId,
    required String response,
    required String adminName,
    required String issueType,
  }) async {
    try {
      await sendDonorNotification(
        donorId: donorId,
        type: 'problem_response',
        title: 'Response to Your Problem Report',
        message: 'Admin $adminName has responded to your problem report: $response',
        additionalData: {
          'response': response,
          'adminName': adminName,
          'issueType': issueType,
        },
      );
    } catch (e) {
      print('Error sending problem response notification: $e');
    }
  }

  /// Send problem report response notification to organization
  static Future<void> sendOrgProblemResponseNotification({
    required String organizationId,
    required String response,
    required String adminName,
    required String issueType,
  }) async {
    try {
      await sendOrganizationNotification(
        organizationId: organizationId,
        type: 'problem_response',
        title: 'Response to Your Problem Report',
        message: 'Admin $adminName has responded to your problem report: $response',
        additionalData: {
          'response': response,
          'adminName': adminName,
          'issueType': issueType,
        },
      );
    } catch (e) {
      print('Error sending organization problem response notification: $e');
    }
  }

  /// Send support response notification to organization
  static Future<void> sendOrgSupportResponseNotification({
    required String organizationId,
    required String response,
    required String adminName,
  }) async {
    try {
      await sendOrganizationNotification(
        organizationId: organizationId,
        type: 'support_response',
        title: 'Response to Your Support Request',
        message: 'Admin $adminName has responded to your support request: $response',
        additionalData: {
          'response': response,
          'adminName': adminName,
        },
      );
    } catch (e) {
      print('Error sending organization support response notification: $e');
    }
  }

  /// Update FCM token for user
  static Future<void> updateFCMToken({
    required String userId,
    required String fcmToken,
    required String userType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://your-firebase-function-url/api/notifications/update-fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: jsonEncode({
          'userId': userId,
          'fcmToken': fcmToken,
          'userType': userType,
        }),
      );
      
      if (response.statusCode == 200) {
        print('FCM token updated successfully');
      } else {
        print('Failed to update FCM token: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  /// Send push notification to specific user
  static Future<void> _sendPushNotification({
    required String userId,
    required String title,
    required String message,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('User not found for push notification: $userId');
        return;
      }

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null) {
        print('No FCM token found for user: $userId');
        return;
      }

      // Send via Firebase Cloud Messaging
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=YOUR_SERVER_KEY', // You'll need to add your FCM server key
        },
        body: jsonEncode({
          'to': fcmToken,
          'notification': {
            'title': title,
            'body': message,
            'sound': 'default',
            'badge': '1',
          },
          'data': data,
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        print('Push notification sent successfully to user: $userId');
      } else {
        print('Failed to send push notification: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  /// Send push notification to topic
  static Future<void> _sendPushNotificationToTopic({
    required String topic,
    required String title,
    required String message,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Send via Firebase Cloud Messaging
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=YOUR_SERVER_KEY', // You'll need to add your FCM server key
        },
        body: jsonEncode({
          'to': '/topics/$topic',
          'notification': {
            'title': title,
            'body': message,
            'sound': 'default',
            'badge': '1',
          },
          'data': data,
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        print('Push notification sent successfully to topic: $topic');
      } else {
        print('Failed to send push notification to topic: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending push notification to topic: $e');
    }
  }

  /// Get Firebase auth token for API calls
  static Future<String> _getAuthToken() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final token = await user.getIdToken();
    if (token == null) throw Exception('Failed to get auth token');
    return token;
  }
} 