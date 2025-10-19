#!/usr/bin/env node

/**
 * Clear all data from Firestore collections
 * Usage: node scripts/clear_all_data.js
 * 
 * WARNING: This will delete ALL data from ALL collections!
 * 
 * Set GOOGLE_APPLICATION_CREDENTIALS environment variable to your service account key path
 * Example: export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
 */

const admin = require('firebase-admin');
const readline = require('readline');
const path = require('path');

// Initialize Firebase Admin using environment variable
if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('\n❌ Error: GOOGLE_APPLICATION_CREDENTIALS environment variable not set!\n');
  console.error('Please set it to your service account key file path:');
  console.error('  export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"\n');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

const COLLECTIONS = [
  'users',
  'annoyances',
  'coaching',
  'suggestions',
  'events',
  'llm_cost'
];

async function deleteCollection(collectionName, batchSize = 500) {
  const collectionRef = db.collection(collectionName);
  const query = collectionRef.limit(batchSize);

  return new Promise((resolve, reject) => {
    deleteQueryBatch(query, resolve, reject);
  });
}

async function deleteQueryBatch(query, resolve, reject) {
  const snapshot = await query.get();

  const batchSize = snapshot.size;
  if (batchSize === 0) {
    resolve();
    return;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();

  process.stdout.write('.');

  // Recurse on the next process tick to avoid blocking
  process.nextTick(() => {
    deleteQueryBatch(query, resolve, reject);
  });
}

async function clearAllData() {
  console.log('\n⚠️  WARNING: This will DELETE ALL DATA from ALL collections!\n');
  console.log('Collections to be cleared:');
  COLLECTIONS.forEach(c => console.log(`  - ${c}`));
  console.log('');

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  return new Promise((resolve) => {
    rl.question('Type "DELETE ALL" to confirm: ', async (answer) => {
      rl.close();
      
      if (answer.trim() !== 'DELETE ALL') {
        console.log('\n❌ Cancelled. No data was deleted.\n');
        resolve();
        return;
      }

      console.log('\n🔥 Deleting all data...\n');

      for (const collectionName of COLLECTIONS) {
        process.stdout.write(`Deleting ${collectionName}...`);
        await deleteCollection(collectionName);
        console.log(` ✓ Done`);
      }

      console.log('\n✅ All data has been deleted!\n');
      resolve();
    });
  });
}

// Run the script
clearAllData()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Error:', error);
    process.exit(1);
  });

