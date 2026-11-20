/**
 * create_owner.js
 *
 * Creates a TurfGo owner account in one shot:
 *   1. Firebase Auth user  →  <username>@turfgo.in
 *   2. Firestore users doc →  role: 'owner'
 *   3. Links existing turf →  sets ownerId on turfs/<turfId>
 *
 * Usage:
 *   node create_owner.js --name "Ace Badminton" --username "aceturf" \
 *                        --password "Pass@123" --turfId "turf_ace_badminton" \
 *                        --city "madurai"
 */

const admin = require('./functions/node_modules/firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db    = admin.firestore();
const auth  = admin.auth();

// ── Parse CLI args ────────────────────────────────────────────────────────────
function getArg(flag) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1 || idx + 1 >= process.argv.length) return null;
  return process.argv[idx + 1].trim();
}

const name     = getArg('--name');
const username = getArg('--username');
const password = getArg('--password');
const turfId   = getArg('--turfId');
const city     = getArg('--city') || 'madurai';

// ── Validate ──────────────────────────────────────────────────────────────────
const missing = [];
if (!name)     missing.push('--name');
if (!username) missing.push('--username');
if (!password) missing.push('--password');
if (!turfId)   missing.push('--turfId');

if (missing.length > 0) {
  console.error('❌  Missing required arguments:', missing.join(', '));
  console.error('');
  console.error('Usage example:');
  console.error('  node create_owner.js \\');
  console.error('    --name "Ace Badminton" \\');
  console.error('    --username "aceturf" \\');
  console.error('    --password "Pass@123" \\');
  console.error('    --turfId "turf_ace_badminton" \\');
  console.error('    --city "madurai"');
  process.exit(1);
}

if (password.length < 6) {
  console.error('❌  Password must be at least 6 characters.');
  process.exit(1);
}

if (username.includes('@')) {
  console.error('❌  --username should be just the prefix, e.g. "aceturf" (not "aceturf@turfgo.in")');
  process.exit(1);
}

const email = `${username}@turfgo.in`;

// ── Main ──────────────────────────────────────────────────────────────────────
async function createOwner() {
  console.log('');
  console.log('🚀  Creating TurfGo owner account...');
  console.log(`    Name     : ${name}`);
  console.log(`    Email    : ${email}`);
  console.log(`    Turf ID  : ${turfId}`);
  console.log(`    City     : ${city}`);
  console.log('');

  // 1. Verify the turf exists before doing anything
  const turfRef  = db.collection('turfs').doc(turfId);
  const turfSnap = await turfRef.get();
  if (!turfSnap.exists) {
    console.error(`❌  Turf "${turfId}" not found in Firestore.`);
    console.error('    Create the turf document first, then run this script.');
    process.exit(1);
  }

  // 2. Create Firebase Auth user
  let userRecord;
  try {
    userRecord = await auth.createUser({
      email,
      password,
      displayName: name,
    });
    console.log(`✅  Auth user created  →  UID: ${userRecord.uid}`);
  } catch (err) {
    if (err.code === 'auth/email-already-exists') {
      // If the auth user already exists, fetch it so we can still sync Firestore
      console.warn(`⚠️   Auth user already exists for ${email} — fetching existing UID.`);
      userRecord = await auth.getUserByEmail(email);
    } else {
      console.error('❌  Failed to create Auth user:', err.message);
      process.exit(1);
    }
  }

  const uid = userRecord.uid;

  // 3. Create Firestore users/{uid} doc
  await db.collection('users').doc(uid).set({
    name:        name,
    phone:       '',
    cityId:      city,
    role:        'owner',
    referralCode: null,
    referredBy:  null,
    createdAt:   admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`✅  Firestore users/${uid} created  →  role: owner`);

  // 4. Link turf to this owner
  await turfRef.update({ ownerId: uid });
  console.log(`✅  Turf "${turfId}" linked  →  ownerId: ${uid}`);

  console.log('');
  console.log('🎉  Done! Owner account is ready.');
  console.log(`    Login username : ${username}`);
  console.log(`    Login password : ${password}`);
  console.log('');
}

createOwner().catch((err) => {
  console.error('❌  Unexpected error:', err.message);
  process.exit(1);
});
