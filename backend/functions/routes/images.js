const express = require('express');
const admin = require('firebase-admin');
const { Storage } = require('@google-cloud/storage');
const { v4: uuidv4 } = require('uuid');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
const storage = new Storage();
const bucket = storage.bucket(admin.storage().bucket().name);

// Apply authentication middleware
router.use(authenticate);

// POST /api/upload-image - Upload image to Firebase Storage
router.post('/', async (req, res) => {
  try {
    const fileName = `images/${req.user.uid}_${uuidv4()}.jpg`;
    const file = bucket.file(fileName);
    await file.save(req.body, {
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