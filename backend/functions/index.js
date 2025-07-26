const functions = require('firebase-functions');
const admin = require('./firebaseAdmin');
const express = require('express');
const cors = require('cors');

const userRoutes = require('./routes/users');
const donationRoutes = require('./routes/donations');
const supportRoutes = require('./routes/support');
const notificationRoutes = require('./routes/notifications');
const reportRoutes = require('./routes/reports');
const imageRoutes = require('./routes/images');

const triggers = require('./triggers/notificationsTriggers');

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// Mount routes
app.use('/api/users', userRoutes);
app.use('/api/donations', donationRoutes);
app.use('/api/support', supportRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/upload-image', imageRoutes);

// Export the API as a Firebase Cloud Function
exports.api = functions.https.onRequest(app);

// Export triggers
exports.onUserCreated = triggers.onUserCreated;
exports.onUserUpdated = triggers.onUserUpdated;
exports.onDonationCreated = triggers.onDonationCreated;
exports.onDonationUpdated = triggers.onDonationUpdated;
exports.onSupportRequestUpdated = triggers.onSupportRequestUpdated;
exports.onIssueUpdated = triggers.onIssueUpdated;