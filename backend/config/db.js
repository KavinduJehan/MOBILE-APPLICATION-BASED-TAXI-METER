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
    } else if (/querysrv|enotfound|econnrefused|getaddrinfo/i.test(error.message)) {
      console.error('[MongoDB Tip] Could not resolve the Atlas SRV record. Check DNS/network access, verify the cluster hostname in MONGO_URI, and try another DNS resolver or network.');
    } else if (/whitelist|timed out|server selection/i.test(error.message)) {
      console.error('[MongoDB Tip] Connection timed out. Check MongoDB Atlas Network Access and allow this machine IP.');
    }
    throw error;
  }
};

module.exports = connectDB;
