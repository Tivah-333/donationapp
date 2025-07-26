const express = require('express');
const admin = require('../firebaseAdmin');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
const db = admin.firestore();

// Apply authentication middleware
router.use(authenticate);

// POST /api/support - Submit support request
router.post('/', authenticate, async (req, res) => {
  try {
    const { name, email, message, timestamp } = req.body;

    if (!name || !email || !message) {
      return res.status(400).json({ error: 'Name, email, and message are required' });
    }

    const supportRequest = {
      name,
      email,
      message,
      userId: req.user.uid,
      timestamp: timestamp
        ? admin.firestore.Timestamp.fromDate(new Date(timestamp))
        : admin.firestore.Timestamp.now(),
      status: 'resolved',
    };

    const docRef = await db.collection('support_requests').add(supportRequest);

    // Notify admins
    const adminUsers = await db.collection('users').where('role', '==', 'Administrator').get();
    const adminFcmTokens = adminUsers.docs
      .filter(doc => doc.data().notificationsEnabled && doc.data().fcmToken)
      .map(doc => doc.data().fcmToken);

    if (adminFcmTokens.length > 0) {
      const message = {
        notification: {
          title: 'New Support Request',
          body: `Support request from ${email}: ${message.substring(0, 50)}...`,
        },
        tokens: adminFcmTokens,
      };

      await admin.messaging().sendMulticast(message);

      // Store notification for each admin
      for (const admin of adminUsers.docs) {
        if (admin.data().notificationsEnabled && doc.data().fcmToken) {
          await db.collection('notifications').add({
            recipientId: admin.id,
            title: 'New Support Request',
            message: `Support request from ${email}: ${message.substring(0, 50)}...`,
            type: 'support_request',
            timestamp: admin.firestore.Timestamp.now(),
            read: false,
            starred: false,
          });
        }
      }
    }

    res.status(200).json({ id: docRef.id, ...supportRequest });
  } catch (error) {
    console.error('Error creating support request:', error);
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/support/:id/respond - Respond to support request (admin only)
router.put('/:id/respond', authenticate, async (req, res) => {
  try {
    if (req.user.role !== 'Administrator') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const { response, status } = req.body;
    if (!response && !status) {
      return res.status(400).json({ error: 'Response or status required' });
    }

    const updates = {};
    if (response) updates.response = response;
    if (status) updates.status = status;
    updates.updatedAt = admin.firestore.Timestamp.now();

    await db.collection('support_requests').doc(req.params.id).update(updates);

    res.status(200).json({ message: 'Support request updated' });
  } catch (error) {
    console.error('Error responding to support request:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/support/issues - Submit problem report
router.post('/issues', authenticate, async (req, res) => {
  try {
    const { description, imageUrl, timestamp } = req.body;

    if (!description) {
      return res.status(400).json({ error: 'Description is required' });
    }

    const issue = {
      description,
      imageUrl: imageUrl || '',
      userId: req.user.uid,
      timestamp: timestamp
        ? admin.firestore.Timestamp.fromDate(new Date(timestamp))
        : admin.firestore.Timestamp.now(),
      status: 'unresolved',
    };

    const docRef = await db.collection('issues').add(issue);

    // Notify admins
    const adminUsers = await db.collection('users').where('role', '==', 'Administrator').get();
    const adminFcmTokens = adminUsers.docs
      .filter(doc => doc.data().notificationsEnabled && doc.data().fcmToken)
      .map(doc => doc.data().fcmToken);

    if (adminFcmTokens.length > 0) {
      const message = {
        notification: {
          title: 'New Problem Report',
          body: `Problem reported by ${req.user.email}: ${description.substring(0, 50)}...`,
        },
        tokens: adminFcmTokens,
      };

      await admin.messaging().sendMulticast(message);

      // Store notification for each admin
      for (const admin of adminUsers.docs) {
        if (admin.data().notificationsEnabled && admin.data().fcmToken) {
          await db.collection('notifications').add({
            recipientId: admin.id,
            title: 'New Problem Report',
            message: `Problem reported by ${req.user.email}: ${description.substring(0, 50)}...`,
            type: 'issue_report',
            timestamp: admin.firestore.Timestamp.now(),
            read: false,
            starred: false,
          });
        }
      }
    }

    res.status(200).json({ id: docRef.id, ...issue });
  } catch (error) {
    console.error('Error creating issue:', error);
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/support/issues/:id/respond - Respond to issue (admin only)
router.put('/issues/:id/respond', authenticate, async (req, res) => {
  try {
    if (req.user.role !== 'Administrator') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const { response, status } = req.body;
    if (!response && !status) {
      return res.status(400).json({ error: 'Response or status required' });
    }

    const updates = {};
    if (response) updates.response = response;
    if (status) updates.status = status;
    updates.updatedAt = admin.firestore.Timestamp.now();

    await db.collection('issues').doc(req.params.id).update(updates);

    res.status(200).json({ message: 'Issue updated' });
  } catch (error) {
    console.error('Error responding to issue:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
