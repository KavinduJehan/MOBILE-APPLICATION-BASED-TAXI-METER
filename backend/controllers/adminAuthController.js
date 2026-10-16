const Driver = require('../models/Driver');

const changePassword = async (req, res) => {
  const newPassword = String(req.body.newPassword || '');
  if (newPassword.length < 12) {
    return res.status(400).json({ message: 'Password must be at least 12 characters' });
  }

  try {
    const admin = await Driver.findOne({ _id: req.user.id, role: 'regulator' });
    if (!admin) return res.status(404).json({ message: 'Admin account not found' });

    admin.password = newPassword;
    admin.requiresPasswordChange = false;
    await admin.save();
    res.json({ message: 'Password changed successfully', requiresPasswordChange: false });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { changePassword };
