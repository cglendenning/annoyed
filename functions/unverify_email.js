const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function unverifyEmail(email) {
  try {
    console.log(`Looking up user: ${email}`);
    const user = await admin.auth().getUserByEmail(email);
    
    console.log(`Found user: ${user.uid}`);
    console.log(`Current emailVerified status: ${user.emailVerified}`);
    
    await admin.auth().updateUser(user.uid, {
      emailVerified: false
    });
    
    console.log(`✓ Email unverified for: ${email}`);
    console.log(`UID: ${user.uid}`);
    console.log('\nYou can now test the email verification flow again!');
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
  process.exit();
}

// Usage: node unverify_email.js your@email.com
const email = process.argv[2];
if (!email) {
  console.error('Usage: node unverify_email.js <email>');
  console.error('Example: node unverify_email.js craig@example.com');
  process.exit(1);
}

unverifyEmail(email);

