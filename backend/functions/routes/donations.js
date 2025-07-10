const express = require('express');
const admin = require('firebase-admin');
const { authenticate, restrictToRole } = require('../middleware/auth');

const router = express.Router();

// Apply authentication middleware
router.use(authenticate);

// GET /api/donations - Fetch donations
router.get('/', async (req, res) => {
  try {
    const { orgId, search } = req.query;
    let query = db.collection('donations').orderBy('timestamp', 'desc');
    if (orgId && req.user.role === 'Organization') {
      query = query.where('orgId', '==', orgId);
    }
    if (search) {
      query = query.where('item', '>=', search).where('item', '<=', search + '\uf8ff');
    }
    const snapshot = await query.get();
    const db = admin.firestore();
    const donations = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(donations);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/donations - Create donation
router.post('/', restrictToRole('Organization'), async (req, res) => {
  try {
    const { item, description, category, location } = req.body;
    const donation = {
      item,
      description,
      category,
      orgId: req.user.uid,
      status: 'pending',
      location: location ? new admin.firestore.GeoPoint(location.latitude, location.longitude) : null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
    const docRef = await db.collection('donations').add(donation);
    await admin.messaging().send({
      topic: `admin_notifications`,
      notification: {
        title: 'New Donation Request',
        body: `Organization ${req.user.email} created a donation request for ${item}.`,
      },
    });
    res.json({ id: docRef.id });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/donations/:id - Update donation
router.put('/:id', restrictToRole('Organization', 'Administrator'), async (req, res) => {
  try {
    const updates = req.body;
    updates.lastEditedAt = admin.firestore.FieldValue.serverTimestamp();
    updates.lastEditedBy = req.user.email;
    await db.collection('donations').doc(req.params.id).update(updates);
    res.json({ message: 'Donation updated successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/donations/:id - Delete donation
router.delete('/:id', restrictToRole('Organization', 'Administrator'), async (req, res) => {
  try {
    await db.collection('donations').doc(req.params.id).delete();
    res.json({ message: 'Donation deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;