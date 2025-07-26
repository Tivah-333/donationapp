const functions = require('firebase-functions');
const admin = require('../firebaseAdmin');
const db = admin.firestore();

// Helper to check collection exists (you used this)
const checkCollectionExists = async (name) => {
  const snapshot = await db.collection(name).limit(1).get();
  return !snapshot.empty;
};

// Firestore trigger: New donation
exports.onDonationCreated = require('firebase-functions').firestore
  .document('donations/{donationId}')
  .onCreate(async (snap, context) => {
    try {
      const donation = snap.data();
      const userId = donation.userId;
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        console.log('User not found:', userId);
        return;
      }

      const userData = userDoc.data();
      if (!userData.notificationsEnabled) {
        console.log('Notifications disabled for user:', userId);
        return;
      }
      const fcmToken = userData.fcmToken;
      if (!fcmToken) {
        console.log('No FCM token for user:', userId);
        return;
      }

      const message = {
        notification: {
          title: 'New Donation Created',
          body: `Your donation of ${donation.quantity} ${donation.category} has been received.`,
        },
        token: fcmToken,
      };

      await admin.messaging().send(message);

      // Store notification in Firestore
      await db.collection('notifications').add({
        recipientId: userId,
        title: 'New Donation',
        message: `Your donation of ${donation.quantity} ${donation.category} has been received.`,
        type: 'donation',
        timestamp: db.Timestamp.now(),
        read: false,
        starred: false,
      });
    } catch (error) {
      console.error('Error sending donation notification:', error);
    }
  });

// Firestore trigger: Donation status update
exports.onDonationUpdated = require('firebase-functions').firestore
  .document('donations/{donationId}')
  .onUpdate(async (change, context) => {
    try {
      const newData = change.after.data();
      const previousData = change.before.data();
      if (newData.status !== previousData.status) {
        const userId = newData.userId;
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) return;
        const userData = userDoc.data();
        if (!userData.notificationsEnabled) return;
        const fcmToken = userData.fcmToken;
        if (!fcmToken) return;

        const message = {
          notification: {
            title: 'Donation Status Updated',
            body: `Your donation of ${newData.quantity} ${newData.category} has been ${newData.status}.`,
          },
          token: fcmToken,
        };

        await admin.messaging().send(message);

        await db.collection('notifications').add({
          recipientId: userId,
          title: 'Donation Status Updated',
          message: `Your donation of ${newData.quantity} ${newData.category} has been ${newData.status}.`,
          type: 'donation',
          timestamp: admin.firestore.Timestamp.now(),
          read: false,
          starred: false,
        });
      }
    } catch (error) {
      console.error('Error sending donation update notification:', error);
    }
  });

// Firestore trigger: New user (organization registration)
exports.onUserCreated = require('firebase-functions').firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    try {
      await checkCollectionExists('users');
      const user = snap.data();
      if (user.role !== 'Organization' || user.status !== 'pending') return;

      const adminUsers = await db.collection('users').where('role', '==', 'Administrator').get();
      const adminFcmTokens = adminUsers.docs
        .filter(doc => doc.data().notificationsEnabled && doc.data().fcmToken)
        .map(doc => doc.data().fcmToken);

      if (adminFcmTokens.length > 0) {
        const message = {
          notification: {
            title: 'New Organization Registration',
            body: `Organization ${user.email} has registered and is pending approval.`,
          },
          tokens: adminFcmTokens,
        };

        await admin.messaging().sendMulticast(message);

        // Store notification for each admin
        for (const admin of adminUsers.docs) {
          if (admin.data().notificationsEnabled && admin.data().fcmToken) {
            await db.collection('notifications').add({
              recipientId: admin.id,
              title: 'New Organization Registration',
              message: `Organization ${user.email} has registered and is pending approval.`,
              type: 'user_registration',
              timestamp: admin.firestore.Timestamp.now(),
              read: false,
              starred: false,
            });
          }
        }
      }
    } catch (error) {
      console.error('Error sending user registration notification:', error);
    }
  });

// Firestore trigger: User update (organization status change)
exports.onUserUpdated = require('firebase-functions').firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    try {
      await checkCollectionExists('users');
      const newData = change.after.data();
      const previousData = change.before.data();
      if (newData.role !== 'Organization' || newData.status === previousData.status) return;

      const userId = change.after.id;
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) return;
      const userData = userDoc.data();
      if (!userData.notificationsEnabled) return;
      const fcmToken = userData.fcmToken;
      if (!fcmToken) return;

      const message = {
        notification: {
          title: 'Organization Status Updated',
          body: `Your organization has been ${newData.status}.`,
        },
        token: fcmToken,
      };

      await admin.messaging().send(message);

      await db.collection('notifications').add({
        recipientId: userId,
        title: 'Organization Status Updated',
        message: `Your organization has been ${newData.status}.`,
        type: 'org_registration',
        timestamp: admin.firestore.Timestamp.now(),
        read: false,
        starred: false,
      });
    } catch (error) {
      console.error('Error sending organization status update notification:', error);
    }
  });

// Firestore trigger: Support request update
exports.onSupportRequestUpdated = require('firebase-functions').firestore
  .document('support_requests/{supportId}')
  .onUpdate(async (change, context) => {
    try {
      await checkCollectionExists('support_requests');
      const newData = change.after.data();
      const previousData = change.before.data();
      const userId = newData.userId;
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) return;
      const userData = userDoc.data();
      if (!userData.notificationsEnabled) return;
      const fcmToken = userData.fcmToken;
      if (!fcmToken) return;

      let notification;
      if (newData.status !== previousData.status) {
        notification = {
          title: 'Support Request Updated',
          body: `Your support request status changed to ${newData.status}.`,
          type: 'support_status_change',
        };
      } else if (newData.response && (!previousData.response || newData.response !== previousData.response)) {
        notification = {
          title: 'New Support Response',
          body: `Admin responded to your support request: ${newData.response.substring(0, 50)}...`,
          type: 'support_response',
        };
      } else {
        return;
      }

      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        token: fcmToken,
      };

      await admin.messaging().send(message);

      await db.collection('notifications').add({
        recipientId: userId,
        title: notification.title,
        message: notification.body,
        type: notification.type,
        timestamp: admin.firestore.Timestamp.now(),
        read: false,
        starred: false,
      });
    } catch (error) {
      console.error('Error sending support request notification:', error);
    }
  });

// Firestore trigger: Issue update
exports.onIssueUpdated = require('firebase-functions').firestore
  .document('issues/{issueId}')
  .onUpdate(async (change, context) => {
    try {
      await checkCollectionExists('issues');
      const newData = change.after.data();
      const previousData = change.before.data();
      const userId = newData.userId;
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) return;
      const userData = userDoc.data();
      if (!userData.notificationsEnabled) return;
      const fcmToken = userData.fcmToken;
      if (!fcmToken) return;

      let notification;
      if (newData.status && newData.status !== previousData.status) {
        notification = {
          title: 'Issue Status Updated',
          body: `Your reported issue status changed to ${newData.status}.`,
          type: 'issue_status_change',
        };
      } else if (newData.response && (!previousData.response || newData.response !== previousData.response)) {
        notification = {
          title: 'New Issue Response',
          body: `Admin responded to your issue: ${newData.response.substring(0, 50)}...`,
          type: 'issue_response',
        };
      } else {
        return;
      }

      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        token: fcmToken,
      };

      await admin.messaging().send(message);

      await db.collection('notifications').add({
        recipientId: userId,
        title: notification.title,
        message: notification.body,
        type: notification.type,
        timestamp: admin.firestore.Timestamp.now(),
        read: false,
        starred: false,
      });
    } catch (error) {
      console.error('Error sending issue notification:', error);
    }
  });