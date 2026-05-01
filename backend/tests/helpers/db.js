require('dotenv').config();
const mongoose = require('mongoose');

const connect = async () => {
  const uri = process.env.MONGO_URI_TEST;
  if (!uri) throw new Error('MONGO_URI_TEST is not set in .env');
  await mongoose.connect(uri);
};

const clearDatabase = async () => {
  const collections = mongoose.connection.collections;
  for (const key in collections) {
    await collections[key].deleteMany({});
  }
};

const closeDatabase = async () => {
  await mongoose.connection.dropDatabase();
  await mongoose.connection.close();
};

module.exports = { connect, clearDatabase, closeDatabase };
