const express = require('express');
const admin = require('firebase-admin');
const { Storage } = require('@google-cloud/storage');
const { v4: uuidv4 } = require('uuid');
const { authenticate, restrictToRole } = require('../middleware/auth');

const router = express.Router();
const db = admin.firestore();
const storage = new Storage();
const bucket = storage.bucket(admin.storage().bucket().name);

// Apply authentication middleware
router.use(authenticate);

// GET /api/users/:id - Fetch user profile
router.get('/:id', async (req, res) => {
  try {
    const userId = req.params.id;
    if (req.user.uid !== userId && req.user.role !== 'Administrator') {
      return res.status(403).json({ error: 'Forbidden: Cannot access other user profiles' });
    }

    const userDoc = await db.collection('users').doc(userId).get();
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
    const { uid, email, role } = req.body;

    if (req.user.uid !== uid) {
      return res.status(403).json({ error: 'Forbidden: Can only create own user' });
    }

    const userData = {
      email,
      role,
      status: role === 'Organization' ? 'pending' : 'approved',
      createdAt: admin.firestore.Timestamp.now(),
      notificationsEnabled: true,
      emailNotifications: true,
    };

    await db.collection('users').doc(uid).set(userData);

    if (role === 'Organization') {
      await admin.messaging().send({
        topic: 'admin_notifications',
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
    const userId = req.params.id;
    if (req.user.uid !== userId && req.user.role !== 'Administrator') {
      return res.status(403).json({ error: 'Forbidden: Cannot update other user profiles' });
    }

    const updates = req.body;
    if (updates.location && updates.location.latitude && updates.location.longitude) {
      updates.location = new admin.firestore.GeoPoint(updates.location.latitude, updates.location.longitude);
    }

    await db.collection('users').doc(userId).update(updates);
    res.json({ message: 'Profile updated successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/users/:id - Delete user (Admins only)
router.delete('/:id', restrictToRole('Administrator'), async (req, res) => {
  try {
    const userId = req.params.id;
    await db.collection('users').doc(userId).delete();
    await admin.auth().deleteUser(userId);
    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/users/:id/profile-picture - Upload profile picture (Base64 version)
router.post('/:id/profile-picture', async (req, res) => {
  try {
    const userId = req.params.id;
    if (req.user.uid !== userId) {
      return res.status(403).json({ error: 'Forbidden: Can only upload own profile picture' });
    }

    const { imageBase64 } = req.body;
    if (!imageBase64) {
      return res.status(400).json({ error: 'Image base64 data required' });
    }

    const buffer = Buffer.from(imageBase64, 'base64');
    const fileName = `profile_pics/${userId}_${uuidv4()}.jpg`;
    const file = bucket.file(fileName);

    await file.save(buffer, {
      metadata: { contentType: 'image/jpeg' },
      public: true,
    });

    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: '2030-01-01',
    });

    await db.collection('users').doc(userId).update({ profileImageUrl: url });
    res.json({ profileImageUrl: url });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
