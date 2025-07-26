const express = require('express');
const admin = require('../firebaseAdmin');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
const db = admin.firestore();

// Apply authentication middleware
router.use(authenticate);

// GET /api/notifications - Fetch notifications
router.get('/', async (req, res) => {
  try {
    const { recipientId, startDate } = req.query;
    let query = db.collection('notifications')
      .where('recipientId', '==', recipientId)
      .orderBy('timestamp', 'desc');
    if (startDate) {
      query = query.where('timestamp', '>=', admin.firestore.Timestamp.fromDate(new Date(startDate)));
    }
    const snapshot = await query.get();
    const notifications = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp.toDate().toISOString(),
    }));
    res.json(notifications);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/notifications/:id/read - Mark notification as read
router.put('/:id/read', async (req, res) => {
  try {
    await db.collection('notifications').doc(req.params.id).update({ read: true });
    res.json({ message: 'Notification marked as read' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/notifications/send - Send push notification
router.post('/send', async (req, res) => {
  try {
    const { recipientId, title, body } = req.body;
    if (!recipientId || !title || !body) {
      return res.status(400).json({ error: 'Missing recipientId, title, or body' });
    }
    const userDoc = await db.collection('users').doc(recipientId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;
    if (!fcmToken) {
      return res.status(400).json({ error: 'No FCM token for user' });
    }

    const message = {
      notification: {
        title,
        body,
      },
      token: fcmToken,
    };

    await admin.messaging().send(message);

    // Store notification in Firestore
    await db.collection('notifications').add({
      recipientId,
      title,
      message: body,
      type: 'message',
      timestamp: admin.firestore.Timestamp.now(),
      read: false,
      starred: false,
    });

    res.status(200).json({ message: 'Notification sent and stored' });
  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;