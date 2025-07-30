const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');

const userRoutes = require('./routes/users');
const donationRoutes = require('./routes/donations');
const supportRoutes = require('./routes/support');
const notificationRoutes = require('./routes/notifications');
const reportRoutes = require('./routes/reports');
const imageRoutes = require('./routes/images');

admin.initializeApp();

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// Mount route handlers
app.use('/api/users', userRoutes);
app.use('/api/donations', donationRoutes);
app.use('/api/support', supportRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/upload-image', imageRoutes);

exports.api = functions.https.onRequest(app);

// Email functionality removed - using Firebase default only
