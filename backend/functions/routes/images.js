const express = require('express');
const admin = require('../firebaseAdmin');
const { Storage } = require('@google-cloud/storage');
const { v4: uuidv4 } = require('uuid');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
const storage = new Storage();
const bucket = storage.bucket(admin.storage().bucket().name);

// Apply authentication middleware
router.use(authenticate);

/**
 * POST /api/images/upload
 * Upload a base64-encoded image to Firebase Storage.
 * Requires JSON body with:
 * - base64Image (string): base64 encoded image data
 * - type (string): either 'profile' or 'donation'
 */
router.post('/upload', async (req, res) => {
  try {
    const { base64Image, type } = req.body;
    const userId = req.user.uid;

    if (!base64Image || !type) {
      return res.status(400).json({ error: 'Image data and type are required' });
    }

    if (!['profile', 'donation'].includes(type)) {
      return res.status(400).json({ error: 'Invalid type. Must be "profile" or "donation"' });
    }

    const folder = type === 'profile' ? 'profile_pics' : 'donation_images';
    const fileName = `${folder}/${userId}_${uuidv4()}.jpg`;
    const file = bucket.file(fileName);

    const buffer = Buffer.from(base64Image, 'base64');

    await file.save(buffer, {
      metadata: { contentType: 'image/jpeg' },
      public: true,
    });

    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: '2030-01-01',
    });

    res.json({ imageUrl: url });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
