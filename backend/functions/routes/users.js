const express = require('express');
const admin = require('../firebaseAdmin');
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
    console.error('Error fetching user profile:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/users - Create new user
router.post('/', async (req, res) => {
  try {
    const { uid, email, role } = req.body;

    if (!uid || !email || !role) {
      return res.status(400).json({ error: 'UID, email, and role are required' });
    }

    if (req.user.uid !== uid) {
      return res.status(403).json({ error: 'Forbidden: Can only create own user' });
    }

    if (!['Donor', 'Organization', 'Administrator'].includes(role)) {
      return res.status(400).json({ error: 'Invalid role' });
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
      const adminUsers = await db.collection('users').where('role', '==', 'Administrator').get();
      const adminFcmTokens = adminUsers.docs
        .filter(doc => doc.data().notificationsEnabled && doc.data().fcmToken)
        .map(doc => doc.data().fcmToken);

      if (adminFcmTokens.length > 0) {
        const message = {
          notification: {
            title: 'New Organization Registration',
            body: `Organization ${email} has registered and is pending approval.`,
          },
          tokens: adminFcmTokens,
        };

        await admin.messaging().sendMulticast(message);

        // Store notification for each admin
        for (const admin of adminUsers.docs) {
          if (admin.data().notificationsEnabled && doc.data().fcmToken) {
            await db.collection('notifications').add({
              recipientId: admin.id,
              title: 'New Organization Registration',
              message: `Organization ${email} has registered and is pending approval.`,
              type: 'user_registration',
              timestamp: admin.firestore.Timestamp.now(),
              read: false,
              starred: false,
            });
          }
        }
      }
    }

    res.status(200).json({ id: uid, ...userData, message: 'User created successfully' });
  } catch (error) {
    console.error('Error creating user:', error);
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

    if (updates.status && !['pending', 'approved', 'rejected'].includes(updates.status)) {
      return res.status(400).json({ error: 'Invalid status. Must be pending, approved, or rejected' });
    }

    if (updates.role && !['Donor', 'Organization', 'Administrator'].includes(updates.role)) {
      return res.status(400).json({ error: 'Invalid role' });
    }

    updates.updatedAt = admin.firestore.Timestamp.now();
    await db.collection('users').doc(userId).update(updates);
    res.json({ message: 'Profile updated successfully' });
  } catch (error) {
    console.error('Error updating user profile:', error);
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
    console.error('Error deleting user:', error);
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
    console.error('Error uploading profile picture:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;