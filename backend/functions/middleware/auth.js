const admin = require('firebase-admin');

// Middleware to verify Firebase ID token and load user role from Firestore
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized: No token provided' });
    }

    const idToken = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.user = decodedToken;

    // Load user role from Firestore if available
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(req.user.uid).get();
    req.user.role = userDoc.exists ? userDoc.data().role : null;

    next();
  } catch (error) {
    res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
};

// Middleware to restrict access by allowed roles
const restrictToRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user.role || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Forbidden: Insufficient permissions' });
    }
    next();
  };
};

module.exports = { authenticate, restrictToRole };
