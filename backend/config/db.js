const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const uri = process.env.MONGO_URI;
    if (!uri) {
      throw new Error('MONGO_URI is not set in backend/.env');
    }
    const conn = await mongoose.connect(uri);
    console.log(`MongoDB connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`DB connection error: ${error.message}`);
    if (/bad auth|authentication failed/i.test(error.message)) {
      console.error('[Atlas Tip] Authentication failed. Check your database username & password in MONGO_URI.');
    } else if (/whitelist|timed out|enotfound/i.test(error.message)) {
      console.error('[Atlas Tip] Network timeout. Ensure your current IP (or 0.0.0.0/0) is in MongoDB Atlas Network Access whitelist.');
    }
    process.exit(1);
  }
};

module.exports = connectDB;
