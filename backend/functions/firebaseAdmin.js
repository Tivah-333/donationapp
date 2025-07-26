const admin = require('firebase-admin');

if (!admin.apps.length) {
    try {
        admin.initializeApp({
            credential: admin.credential.applicationDefault(),
            storageBucket: 'donationapp-3c.appspot.com',
            databaseURL: "https://donationapp-3c-default-rtdb.firebaseio.com",
            projectId: 'donationapp-3c'
        });
        console.log('Firebase Admin SDK initialized successfully');
    }   catch (error) {
        console.error('Error initializing Firebase Admin SDK:', error);
        throw error;
    }
}

module.exports = admin;
