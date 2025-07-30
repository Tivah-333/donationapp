import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize FCM
  static Future<void> initialize() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('User granted permission: ${settings.authorizationStatus}');

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      String? token = await _messaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        await _saveTokenToDatabase(token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: $newToken');
        _saveTokenToDatabase(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print('Message also contained a notification: ${message.notification}');
          _showLocalNotification(message);
        }
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('App opened from notification: ${message.data}');
        _handleNotificationTap(message);
      });

      // Check if app was opened from notification when it was terminated
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        print('App opened from terminated state: ${initialMessage.data}');
        _handleNotificationTap(initialMessage);
      }

    } catch (e) {
      print('Error initializing FCM: $e');
    }
  }

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Local notification tapped: ${response.payload}');
      },
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      platformChannelSpecifics,
      payload: message.data.toString(),
    );
  }

  // Save FCM token to database
  static Future<void> _saveTokenToDatabase(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        print('Saving FCM token for user: ${user.uid}');
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token saved to database for user: ${user.uid}');
      } else {
        print('❌ No user logged in, cannot save FCM token');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  // Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    // Handle different notification types
    final data = message.data;
    final type = data['type'];

    switch (type) {
      case 'donation_assigned':
        // Navigate to donation details
        break;
      case 'support_response':
        // Navigate to support page
        break;
      case 'problem_response':
        // Navigate to problem reports
        break;
      case 'dropoff_assignment':
        // Navigate to donation assignment
        break;
      default:
        // Default handling
        break;
    }
  }

  // Manually trigger FCM token generation (for testing)
  static Future<void> generateAndSaveToken() async {
    try {
      print('🔄 Manually generating FCM token...');
      
      String? token = await _messaging.getToken();
      if (token != null) {
        print('✅ Generated FCM Token: $token');
        await _saveTokenToDatabase(token);
      } else {
        print('❌ Failed to generate FCM token');
      }
    } catch (e) {
      print('❌ Error generating FCM token: $e');
      print('This is normal for emulators or devices without Google Play Services');
    }
  }

  // Subscribe to topics
  static Future<void> subscribeToTopics() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get user role
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final role = userDoc.data()?['role'];
          
          // Subscribe based on role
          switch (role) {
            case 'Donor':
              await _messaging.subscribeToTopic('donors');
              break;
            case 'Organization':
              await _messaging.subscribeToTopic('organizations');
              break;
            case 'Administrator':
              await _messaging.subscribeToTopic('admins');
              break;
          }
        }
      }
    } catch (e) {
      print('Error subscribing to topics: $e');
    }
  }

  // Unsubscribe from topics
  static Future<void> unsubscribeFromTopics() async {
    try {
      await _messaging.unsubscribeFromTopic('donors');
      await _messaging.unsubscribeFromTopic('organizations');
      await _messaging.unsubscribeFromTopic('admins');
    } catch (e) {
      print('Error unsubscribing from topics: $e');
    }
  }

  // Get FCM token
  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }
  

}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
  print('Message data: ${message.data}');
  print('Message notification: ${message.notification}');
} 