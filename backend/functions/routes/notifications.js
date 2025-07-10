const express = require('express');
const admin = require('firebase-admin');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// Apply authentication middleware
router.use(authenticate);

// GET /api/notifications - Fetch notifications
router.get('/', async (req, res) => {
  try {
    const db = admin.firestore();
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

module.exports = router;