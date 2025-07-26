const express = require('express');
const admin = require('../firebaseAdmin');
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
    console.error('Error fetching donations:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/donations - Donors or Organizations can create donation requests
router.post('/', async (req, res) => {
  try {
    const { item, category, quantity, deliveryOption, description, locationName, locationCoords, location, imageUrl } = req.body;

    const donation = {
      item: item || null,
      category: category || 'Other',
      quantity: parseInt(quantity) || 1,
      deliveryOption: deliveryOption || 'Pickup',
      description: description || '',
      locationName: locationName || 'Unknown',
      locationCoords: locationCoords ? new admin.firestore.GeoPoint(locationCoords.latitude, locationCoords.longitude) : null,
      location: location ? new admin.firestore.GeoPoint(location.latitude, location.longitude) : null,
      imageUrl: imageUrl || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: 'pending',
    };

    if (req.user.role === 'Organization') {
      donation.orgId = req.user.uid;
    } else {
      donation.userId = req.user.uid;
    }

    const docRef = await db.collection('donations').add(donation);

    // Notify admins
    const adminUsers = await db.collection('users').where('role', '==', 'Administrator').get();
    const adminFcmTokens = adminUsers.docs
      .filter(doc => doc.data().notificationsEnabled && doc.data().fcmToken)
      .map(doc => doc.data().fcmToken);

    if (adminFcmTokens.length > 0) {
      const message = {
        notification: {
          title: 'New Donation Request',
          body: `${req.user.email} created a donation request for ${item} (${category}).`,
        },
        tokens: adminFcmTokens,
      };

      await admin.messaging().sendMulticast(message);

      // Store notification for each admin
      for (const admin of adminUsers.docs) {
        if (admin.data().notificationsEnabled && admin.data().fcmToken) {
          await db.collection('notifications').add({
            recipientId: admin.id,
            title: 'New Donation Request',
            message: `${req.user.email} donated ${item} (${category}) - Quantity: ${donation.quantity}`,
            type: 'donation_request',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
            starred: false,
            donorEmail: req.user.email,
            donationId: docRef.id,
          });
        }
      }
    }

    res.json({ id: docRef.id, message: 'Donation created' });
  } catch (error) {
    console.error('Error creating donation:', error);
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
    console.error('Error updating donation:', error);
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
    console.error('Error deleting donation:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;