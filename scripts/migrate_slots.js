/**
 * migrate_slots.js
 *
 * One-time migration: backfills courtCount, coachingReserved, bookedCount,
 * and bookingIds on existing slot documents that predate multi-court support.
 *
 * Safe to run multiple times — skips slots that already have courtCount set.
 *
 * Usage: node scripts/migrate_slots.js
 */

const admin = require('../functions/node_modules/firebase-admin');
const serviceAccount = require('../serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function migrate() {
  console.log('🔄  Starting slot migration...\n');

  // Fetch all turfs
  const turfsSnap = await db.collection('turfs').get();
  let totalSlots    = 0;
  let migratedSlots = 0;
  let skippedSlots  = 0;

  for (const turfDoc of turfsSnap.docs) {
    const turfData        = turfDoc.data();
    const courtCounts     = turfData.courtCounts     ?? {};
    const coachingSchedule = turfData.coachingSchedule ?? [];

    console.log(`📍  Turf: ${turfData.name} (${turfDoc.id})`);

    const slotsSnap = await db
      .collection('turfs')
      .doc(turfDoc.id)
      .collection('slots')
      .get();

    if (slotsSnap.empty) {
      console.log('    No slots found.\n');
      continue;
    }

    // Process in batches of 400
    const BATCH_SIZE = 400;
    let batch = db.batch();
    let batchCount = 0;

    for (const slotDoc of slotsSnap.docs) {
      totalSlots++;
      const data = slotDoc.data();

      // Skip if already migrated
      if (data.courtCount !== undefined) {
        skippedSlots++;
        continue;
      }

      // Determine court count from turf config
      const sport       = data.sport ?? '';
      const courtCount  = courtCounts[sport] ?? 1;

      // Determine hour from startTime (e.g. "18:00" → 18)
      const hour = parseInt((data.startTime ?? '0:00').split(':')[0], 10);

      // Calculate coaching reservation for this slot
      const coachingReserved = coachingSchedule
        .filter(c => c.sport === sport && hour >= c.fromHour && hour < c.toHour)
        .reduce((sum, c) => sum + c.courts, 0);
      const clampedCoaching = Math.min(coachingReserved, courtCount);

      // bookedCount: 1 if already booked, 0 otherwise
      const wasBooked   = data.isBooked === true;
      const bookedCount = wasBooked ? 1 : 0;

      // bookingIds: wrap existing bookingId if present
      const bookingIds = data.bookingId ? [data.bookingId] : [];

      batch.update(slotDoc.ref, {
        courtCount,
        coachingReserved: clampedCoaching,
        bookedCount,
        bookingIds,
      });

      migratedSlots++;
      batchCount++;

      if (batchCount >= BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    console.log(`    ✓  ${migratedSlots} migrated, ${skippedSlots} skipped\n`);
  }

  console.log('──────────────────────────────────────');
  console.log(`✅  Migration complete!`);
  console.log(`    Total slots found : ${totalSlots}`);
  console.log(`    Migrated          : ${migratedSlots}`);
  console.log(`    Already up-to-date: ${skippedSlots}`);
  process.exit(0);
}

migrate().catch((e) => { console.error('❌  Error:', e); process.exit(1); });
