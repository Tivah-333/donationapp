const express = require('express');
const admin = require('firebase-admin');
const { Storage } = require('@google-cloud/storage');
const { v4: uuidv4 } = require('uuid');
const { authenticate, restrictToRole } = require('../middleware/auth');

const router = express.Router();
const storage = new Storage();
const bucket = storage.bucket(admin.storage().bucket().name);

// Apply authentication middleware
router.use(authenticate);

// GET /api/users/:id - Fetch user profile
router.get('/:id', async (req, res) => {
  try {
    if (req.user.uid !== req.params.id && req.user.role !== 'Administrator') {
      return res.status(403).json({ error: 'Forbidden: Cannot access other user profiles' });
    }
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(req.params.id).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(userDoc.data());
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/users - Create new user
router.post('/', async (req, res) => {
  try {
    const { uid, email, role, status, createdAt } = req.body;
    if (req.user.uid !== uid) {
      return res.status(403).json({ error: 'Forbidden: Can only create own user' });
    }
    const userData = {
      email,
      role,
      status: role === 'Organization' ? 'pending' : 'approved',
      createdAt: admin.firestore.Timestamp.fromDate(new Date(createdAt)),
      notificationsEnabled: true,
      emailNotifications: true,
    };
    await db.collection('users').doc(uid).set(userData);
    if (role === 'Organization') {
      await admin.messaging().send({
        topic: `admin_notifications`,
        notification: {
          title: 'New Organization Registration',
          body: `Organization ${email} has registered and is pending approval.`,
        },
      });
    }
    res.status(200).json({ message: 'User created successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/users/:id - Update user profile
router.put('/:id', async (req, res) => {
  try {
    if (req.user.uid !== req.params.id && req.user.role !== 'Administrator') {
      return res.status(403).json({ error: 'Forbidden: Cannot update other user profiles' });
    }
    const updates = req.body;
    if (updates.location) {
      updates.location = new admin.firestore.GeoPoint(
        updates.location.latitude,
        updates.location.longitude
      );
    }
    await db.collection('users').doc(req.params.id).update(updates);
    res.json({ message: 'Profile updated successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/users/:id - Delete user
router.delete('/:id', restrictToRole('Administrator'), async (req, res) => {
  try {
    await db.collection('users').doc(req.params.id).delete();
    await admin.auth().deleteUser(req.params.id);
    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/users/:id/profile-picture - Upload profile picture
router.post('/:id/profile-picture', async (req, res) => {
  try {
    if (req.user.uid !== req.params.id) {
      return res.status(403).json({ error: 'Forbidden: Can only upload own profile picture' });
    }
    const fileName = `profile_pics/${req.params.id}_${uuidv4()}.jpg`;
    const file = bucket.file(fileName);
    await file.save(req.body, {
      metadata: { contentType: 'image/jpeg' },
      public: true,
    });
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: '2030-01-01',
    });
    await db.collection('users').doc(req.params.id).update({ profileImageUrl: url });
    res.json({ profileImageUrl: url });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;