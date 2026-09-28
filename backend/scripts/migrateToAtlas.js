/**
 * Data migration script: copies all data from local MongoDB to MongoDB Atlas
 * Usage: node scripts/migrateToAtlas.js
 *
 * Requirements:
 * - Local MongoDB running (or specify LOCAL_MONGO_URI in .env or as argument)
 * - MONGO_URI in .env set to your MongoDB Atlas connection string
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const mongoose = require('mongoose');

const LOCAL_URI = process.env.LOCAL_MONGO_URI || 'mongodb://127.0.0.1:27017/taximeter';
const ATLAS_URI = process.env.MONGO_URI;

if (!ATLAS_URI || !ATLAS_URI.startsWith('mongodb')) {
  console.error('ERROR: MONGO_URI in backend/.env is not configured with a valid MongoDB Atlas URI.');
  console.error('Example: MONGO_URI=mongodb+srv://<user>:<password>@cluster0.xxxxx.mongodb.net/taximeter?retryWrites=true&w=majority');
  process.exit(1);
}

if (ATLAS_URI.includes('localhost') || ATLAS_URI.includes('127.0.0.1')) {
  console.error('ERROR: MONGO_URI currently points to localhost.');
  console.error('Please update MONGO_URI in backend/.env to your MongoDB Atlas connection string before running migration.');
  process.exit(1);
}

async function migrate() {
  console.log('--- MongoDB Local to Atlas Migration ---');
  console.log(`Source (Local): ${LOCAL_URI}`);
  console.log(`Destination (Atlas): ${ATLAS_URI.replace(/:([^:@]+)@/, ':****@')}\n`);

  let localConn;
  let atlasConn;

  try {
    console.log('Connecting to local MongoDB...');
    localConn = await mongoose.createConnection(LOCAL_URI).asPromise();
    console.log('Connected to local MongoDB.');

    console.log('Connecting to MongoDB Atlas...');
    atlasConn = await mongoose.createConnection(ATLAS_URI).asPromise();
    console.log('Connected to MongoDB Atlas.\n');

    const collections = await localConn.db.listCollections().toArray();
    console.log(`Found ${collections.length} collections in local database:`);
    collections.forEach((c) => console.log(` - ${c.name}`));
    console.log('');

    for (const col of collections) {
      const colName = col.name;
      if (colName.startsWith('system.')) continue;

      const localCollection = localConn.collection(colName);
      const atlasCollection = atlasConn.collection(colName);

      const docs = await localCollection.find({}).toArray();
      if (docs.length === 0) {
        console.log(`[${colName}] 0 documents found, skipping.`);
        continue;
      }

      console.log(`[${colName}] Migrating ${docs.length} documents...`);

      // Clear existing in Atlas collection to avoid duplicate key errors
      await atlasCollection.deleteMany({});
      await atlasCollection.insertMany(docs);
      console.log(`[${colName}] Successfully copied ${docs.length} documents to Atlas.`);
    }

    console.log('\nMigration to MongoDB Atlas completed successfully!');
  } catch (error) {
    console.error('\nMigration failed:', error.message);
    if (error.message.includes('Authentication failed') || error.message.includes('bad auth')) {
      console.error('Tip: Check your Atlas username and password in MONGO_URI.');
    } else if (error.message.includes('timed out') || error.message.includes('whitelist')) {
      console.error('Tip: Check Atlas Network Access. Ensure IP 0.0.0.0/0 is allowed in MongoDB Atlas.');
    }
  } finally {
    if (localConn) await localConn.close();
    if (atlasConn) await atlasConn.close();
    process.exit(0);
  }
}

migrate();
