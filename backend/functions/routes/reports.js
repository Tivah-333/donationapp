const express = require('express');
const admin = require('../firebaseAdmin');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
const db = admin.firestore();

// Apply authentication middleware
router.use(authenticate);

// GET /api/reports - Fetch donation reports
router.get('/', async (req, res) => {
  try {
    const { category, fromDate, toDate } = req.query;
    const usersSnapshot = await db.collection('users').get();
    const donationsSnapshot = await db.collection('donations')
      .orderBy('timestamp', 'desc')
      .get();

    let totalDonors = 0, totalOrganizations = 0;
    for (const doc of usersSnapshot.docs) {
      const role = doc.data().role;
      if (role === 'Donor') totalDonors++;
      if (role === 'Organization') totalOrganizations++;
    }

    const categoryCounts = {};
    const dailyCounts = {};
    let totalDonations = 0;

    for (const doc of donationsSnapshot.docs) {
      const data = doc.data();
      const timestamp = data.timestamp?.toDate();
      const donationCategory = data.category || 'Unknown';

      if (timestamp) {
        if (fromDate && timestamp < new Date(fromDate)) continue;
        if (toDate && timestamp > new Date(toDate)) continue;
        if (category && category !== 'All' && category !== donationCategory) continue;

        totalDonations++;
        categoryCounts[donationCategory] = (categoryCounts[donationCategory] || 0) + 1;

        const date = timestamp.toISOString().split('T')[0];
        dailyCounts[date] = (dailyCounts[date] || 0) + 1;
      }
    }

    const donationData = Object.entries(dailyCounts)
      .map(([date, count]) => ({ date, count }))
      .sort((a, b) => new Date(a.date) - new Date(b.date));

    res.json({
      totalDonors,
      totalOrganizations,
      totalDonations,
      categoryCounts,
      donationData,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;