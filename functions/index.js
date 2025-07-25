const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendDonationStatusNotification = functions.firestore
  .document('donations/{donationId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only proceed if status has changed
    if (before.status === after.status) {
      return null;
    }

    const newStatus = after.status;
    const userId = after.userId;

    // Only notify for specific statuses
    if (newStatus === 'picked up' || newStatus === 'delivered') {
      try {
        // Fetch user's FCM token from Firestore
        const userDoc = await admin.firestore().collection('users').doc(userId).get();

        if (!userDoc.exists) {
          console.log(`User not found: ${userId}`);
          return null;
        }

        const userData = userDoc.data();
        const token = userData?.fcmToken;

        if (!token) {
          console.log(`No FCM token for user: ${userId}`);
          return null;
        }

        const payload = {
          notification: {
            title: 'Donation Status Update',
            body: `Your donation status is now "${newStatus}".`,
          }
        };

        const response = await admin.messaging().sendToDevice(token, payload);
        console.log('Notification sent successfully:', response);
      } catch (error) {
        console.error('Error sending notification:', error);
      }
    }

    return null;
  });
