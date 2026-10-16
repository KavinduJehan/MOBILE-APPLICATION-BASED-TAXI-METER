const jwt = require('jsonwebtoken');
const Driver = require('../models/Driver');

const protect = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Not authorized, no token' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch {
    return res.status(401).json({ message: 'Not authorized, invalid token' });
  }
};

const requireRole = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user?.role)) {
    return res.status(403).json({ message: 'Forbidden: insufficient role' });
  }
  next();
};

const requirePasswordChangeComplete = async (req, res, next) => {
  try {
    const admin = await Driver.findById(req.user.id).select('role requiresPasswordChange');
    if (!admin || admin.role !== 'regulator') {
      return res.status(401).json({ message: 'Admin account not found' });
    }
    if (admin.requiresPasswordChange) {
      return res.status(403).json({
        code: 'PASSWORD_CHANGE_REQUIRED',
        message: 'Change your password before using admin features',
      });
    }
    next();
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { protect, requireRole, requirePasswordChangeComplete };
