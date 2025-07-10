const admin = require('firebase-admin');

// Middleware to verify Firebase ID token
const authenticate = async (req, res, next) => {
  try {
    const idToken = req.headers.authorization?.split('Bearer ')[1];
    if (!idToken) {
      return res.status(401).json({ error: 'Unauthorized: No token provided' });
    }
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.user = decodedToken;
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(req.user.uid).get();
    req.user.role = userDoc.exists ? userDoc.data().role : null;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
};

// Middleware to restrict access by role
const restrictToRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user.role || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Forbidden: Insufficient permissions' });
    }
    next();
  };
};

module.exports = { authenticate, restrictToRole };