const admin = require('./functions/node_modules/firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const TURF_ID = 'turf_ace_badminton';
const SPORTS = ['Badminton'];
const PRICE_PER_HOUR = 400;
const START_HOUR = 6;   // 6 AM
const END_HOUR = 22;    // last slot at 9 PM (ends 10 PM)

// Seed for today + next 7 days
const dates = [];
for (let i = 0; i < 7; i++) {
  const d = new Date();
  d.setDate(d.getDate() + i);
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  dates.push(`${yyyy}-${mm}-${dd}`);
}

async function seed() {
  const slotsRef = db.collection('turfs').doc(TURF_ID).collection('slots');
  let total = 0;

  for (const date of dates) {
    const batch = db.batch();
    for (const sport of SPORTS) {
      for (let hour = START_HOUR; hour < END_HOUR; hour++) {
        const startTime = `${String(hour).padStart(2, '0')}:00`;
        const endTime = `${String(hour + 1).padStart(2, '0')}:00`;
        const slotId = `${date}_${sport.toLowerCase()}_${startTime}`;
        batch.set(slotsRef.doc(slotId), {
          date,
          startTime,
          endTime,
          sport,
          price: PRICE_PER_HOUR,
          isBooked: false,
          bookingId: null,
          lockedUntil: null,
          lockedBy: null,
        }, { merge: true });
        total++;
      }
    }
    await batch.commit();
    console.log(`✓ Seeded ${date}`);
  }

  console.log(`\nDone! ${total} slots created for ${TURF_ID}`);
  process.exit(0);
}

seed().catch((e) => { console.error(e); process.exit(1); });
