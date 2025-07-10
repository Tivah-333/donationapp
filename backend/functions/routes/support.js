const express = require('express');
const admin = require('firebase-admin');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// Apply authentication middleware
router.use(authenticate);

// POST /api/support - Submit support request
router.post('/', async (req, res) => {
  try {
    const { name, email, message, timestamp } = req.body;
    const db = admin.firestore();
    const supportRequest = {
      name,
      email,
      message,
      userId: req.user.uid,
      timestamp: admin.firestore.Timestamp.fromDate(new Date(timestamp)),
    };
    await db.collection('support_requests').add(supportRequest);
    await admin.messaging().send({
      topic: `admin_notifications`,
      notification: {
        title: 'New Support Request',
        body: `Support request from ${email}: ${message.substring(0, 50)}...`,
      },
    });
    res.json({ message: 'Support request submitted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/issues - Submit problem report
router.post('/issues', async (req, res) => {
  try {
    const { description, imageUrl, timestamp } = req.body;
    const issue = {
      description,
      imageUrl: imageUrl || '',
      userId: req.user.uid,
      timestamp: admin.firestore.Timestamp.fromDate(new Date(timestamp)),
    };
    await db.collection('issues').add(issue);
    await admin.messaging().send({
      topic: `admin_notifications`,
      notification: {
        title: 'New Problem Report',
        body: `Problem reported by ${req.user.email}: ${description.substring(0, 50)}...`,
      },
    });
    res.json({ message: 'Problem reported successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;