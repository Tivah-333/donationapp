const express = require('express');
const admin = require('firebase-admin');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// Apply authentication middleware
router.use(authenticate);

// POST /api/notifications/send-donor-notification - Send push notification to donor
router.post('/send-donor-notification', async (req, res) => {
  try {
    const { donorId, title, message, data, type } = req.body;
    
    // Get donor's FCM token
    const donorDoc = await admin.firestore().collection('users').doc(donorId).get();
    if (!donorDoc.exists) {
      return res.status(404).json({ error: 'Donor not found' });
    }
    
    const donorData = donorDoc.data();
    const fcmToken = donorData.fcmToken;
    
    if (!fcmToken) {
      return res.status(400).json({ error: 'No FCM token found for donor' });
    }
    
    // Prepare notification payload
    const payload = {
      notification: {
        title: title,
        body: message,
        sound: 'default',
        badge: '1'
      },
      data: {
        type: type || 'general',
        ...data
      },
      token: fcmToken
    };
    
    // Send push notification
    const response = await admin.messaging().send(payload);
    
    // Also store in Firestore for in-app notifications
    await admin.firestore().collection('donor_notifications').add({
      donorId: donorId,
      type: type || 'general',
      title: title,
      message: message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      ...data
    });
    
    console.log('Donor notification sent successfully:', response);
    res.json({ success: true, messageId: response });
    
  } catch (error) {
    console.error('Error sending donor notification:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/notifications/dropoff-assignment - Notify donor about far organization assignment
router.post('/dropoff-assignment', async (req, res) => {
  try {
    const { donorId, organizationName, organizationLocation, donorLocation, donationId, category, title } = req.body;
    
    const notificationTitle = '⚠️ Far Organization Assignment';
    const notificationMessage = `Your donation "$title" ($category) has been assigned to ${organizationName} which is far from your location (${donorLocation}). They are located in ${organizationLocation}. Do you want to accept or reject this assignment?`;
    
    const payload = {
      notification: {
        title: notificationTitle,
        body: notificationMessage,
        sound: 'default',
        badge: '1'
      },
      data: {
        type: 'dropoff_assignment',
        donationId: donationId,
        organizationName: organizationName,
        organizationLocation: organizationLocation,
        donorLocation: donorLocation,
        category: category,
        title: title,
        requiresAction: 'true'
      },
      token: await getDonorFCMToken(donorId)
    };
    
    const response = await admin.messaging().send(payload);
    
    // Store in Firestore
    await admin.firestore().collection('donor_notifications').add({
      donorId: donorId,
      type: 'dropoff_assignment',
      title: notificationTitle,
      message: notificationMessage,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      requiresAction: true,
      donationId: donationId,
      organizationName: organizationName,
      organizationLocation: organizationLocation,
      donorLocation: donorLocation,
      category: category,
      title: title
    });
    
    res.json({ success: true, messageId: response });
    
  } catch (error) {
    console.error('Error sending dropoff assignment notification:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/notifications/support-response - Notify donor about support response
router.post('/support-response', async (req, res) => {
  try {
    const { donorId, response, adminName } = req.body;
    
    const notificationTitle = 'Support Response';
    const notificationMessage = `You have received a response to your support request: ${response}`;
    
    const payload = {
      notification: {
        title: notificationTitle,
        body: notificationMessage,
        sound: 'default',
        badge: '1'
      },
      data: {
        type: 'support_response',
        response: response,
        adminName: adminName
      },
      token: await getDonorFCMToken(donorId)
    };
    
    const responseResult = await admin.messaging().send(payload);
    
    // Store in Firestore
    await admin.firestore().collection('donor_notifications').add({
      donorId: donorId,
      type: 'support_response',
      title: notificationTitle,
      message: notificationMessage,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      response: response,
      adminName: adminName
    });
    
    res.json({ success: true, messageId: responseResult });
    
  } catch (error) {
    console.error('Error sending support response notification:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/notifications/problem-response - Notify donor about problem report response
router.post('/problem-response', async (req, res) => {
  try {
    const { donorId, response, adminName, issueType } = req.body;
    
    const notificationTitle = 'Problem Report Response';
    const notificationMessage = `You have received a response to your ${issueType} report: ${response}`;
    
    const payload = {
      notification: {
        title: notificationTitle,
        body: notificationMessage,
        sound: 'default',
        badge: '1'
      },
      data: {
        type: 'problem_response',
        response: response,
        adminName: adminName,
        issueType: issueType
      },
      token: await getDonorFCMToken(donorId)
    };
    
    const responseResult = await admin.messaging().send(payload);
    
    // Store in Firestore
    await admin.firestore().collection('donor_notifications').add({
      donorId: donorId,
      type: 'problem_response',
      title: notificationTitle,
      message: notificationMessage,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      response: response,
      adminName: adminName,
      issueType: issueType
    });
    
    res.json({ success: true, messageId: responseResult });
    
  } catch (error) {
    console.error('Error sending problem response notification:', error);
    res.status(500).json({ error: error.message });
  }
});

// Helper function to get donor FCM token
async function getDonorFCMToken(donorId) {
  const donorDoc = await admin.firestore().collection('users').doc(donorId).get();
  if (!donorDoc.exists) {
    throw new Error('Donor not found');
  }
  
  const donorData = donorDoc.data();
  const fcmToken = donorData.fcmToken;
  
  if (!fcmToken) {
    throw new Error('No FCM token found for donor');
  }
  
  return fcmToken;
}

// GET /api/notifications/donor/:donorId - Get donor notifications
router.get('/donor/:donorId', async (req, res) => {
  try {
    const { donorId } = req.params;
    const { limit = 50 } = req.query;
    
    const snapshot = await admin.firestore()
      .collection('donor_notifications')
      .where('donorId', '==', donorId)
      .orderBy('timestamp', 'desc')
      .limit(parseInt(limit))
      .get();
    
    const notifications = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp.toDate().toISOString()
    }));
    
    res.json(notifications);
  } catch (error) {
    console.error('Error fetching donor notifications:', error);
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/notifications/donor/:notificationId/read - Mark donor notification as read
router.put('/donor/:notificationId/read', async (req, res) => {
  try {
    await admin.firestore()
      .collection('donor_notifications')
      .doc(req.params.notificationId)
      .update({ read: true });
    
    res.json({ success: true });
  } catch (error) {
    console.error('Error marking notification as read:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/notifications/update-fcm-token - Update donor's FCM token
router.post('/update-fcm-token', async (req, res) => {
  try {
    const { userId, fcmToken, userType } = req.body;
    
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({ 
        fcmToken: fcmToken,
        lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp()
      });
    
    res.json({ success: true });
  } catch (error) {
    console.error('Error updating FCM token:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;