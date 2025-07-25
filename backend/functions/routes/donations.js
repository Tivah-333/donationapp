const express = require('express');
const admin = require('firebase-admin');
const { authenticate, restrictToRole } = require('../middleware/auth');

const router = express.Router();
const db = admin.firestore();

// Apply authentication middleware
router.use(authenticate);

// GET /api/donations - Fetch donations for user or organization
router.get('/', async (req, res) => {
  try {
    const { orgId, search } = req.query;
    let query = db.collection('donations').orderBy('timestamp', 'desc');

    if (req.user.role === 'Donor') {
      query = query.where('userId', '==', req.user.uid);
    } else if (req.user.role === 'Organization' && orgId) {
      query = query.where('orgId', '==', orgId);
    }

    if (search) {
      query = query.where('item', '>=', search).where('item', '<=', search + '\uf8ff');
    }

    const snapshot = await query.get();
    const donations = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(donations);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/donations - Donors or Organizations can create donation requests
router.post('/', async (req, res) => {
  try {
    const { item, category, quantity, deliveryOption, description, locationName, locationCoords, location } = req.body;

    const donation = {
      item: item || null,
      category: category || 'Other',
      quantity: parseInt(quantity) || 1,
      deliveryOption: deliveryOption || 'Pickup',
      description: description || '',
      locationName: locationName || 'Unknown',
      locationCoords: locationCoords ? new admin.firestore.GeoPoint(locationCoords.latitude, locationCoords.longitude) : null,
      location: location ? new admin.firestore.GeoPoint(location.latitude, location.longitude) : null,
      imageUrl: req.body.imageUrl || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: 'pending',
    };

    if (req.user.role === 'Organization') {
      donation.orgId = req.user.uid;
    } else {
      donation.userId = req.user.uid;
    }

    const docRef = await db.collection('donations').add(donation);

    // ✅ Add Firestore notification here
    await db.collection('notifications').add({
      title: `New Donation from ${req.user.email}`,
      message: `${req.user.email} donated ${item} (${category}) - Quantity: ${donation.quantity} - ${new Date().toLocaleDateString()} at ${new Date().toLocaleTimeString()}`,
      type: 'donation',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      starred: false,
      donorEmail: req.user.email,
      donationId: docRef.id,
    });

    if (req.user.role === 'Organization') {
      await admin.messaging().send({
        topic: 'admin_notifications',
        notification: {
          title: 'New Donation Request',
          body: `Organization ${req.user.email} created a donation request for ${item}.`,
        },
      });
    }

    res.json({ id: docRef.id, message: 'Donation created' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/donations/:id - Update donation (Org/Admin/Owner)
router.put('/:id', async (req, res) => {
  try {
    const docRef = db.collection('donations').doc(req.params.id);
    const doc = await docRef.get();

    if (!doc.exists) {
      return res.status(404).json({ error: 'Donation not found' });
    }

    const data = doc.data();

    if (
      req.user.role === 'Donor' && data.userId !== req.user.uid ||
      req.user.role === 'Organization' && data.orgId !== req.user.uid
    ) {
      return res.status(403).json({ error: 'Unauthorized to update this donation' });
    }

    const updates = req.body;
    updates.lastEditedAt = admin.firestore.FieldValue.serverTimestamp();
    updates.lastEditedBy = req.user.email;

    await docRef.update(updates);
    res.json({ message: 'Donation updated successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/donations/:id - Delete donation (Org/Admin/Owner)
router.delete('/:id', async (req, res) => {
  try {
    const docRef = db.collection('donations').doc(req.params.id);
    const doc = await docRef.get();

    if (!doc.exists) {
      return res.status(404).json({ error: 'Donation not found' });
    }

    const data = doc.data();

    if (
      req.user.role === 'Donor' && data.userId !== req.user.uid ||
      req.user.role === 'Organization' && data.orgId !== req.user.uid
    ) {
      return res.status(403).json({ error: 'Unauthorized to delete this donation' });
    }

    await docRef.delete();
    res.json({ message: 'Donation deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
