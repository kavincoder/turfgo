import * as admin from "firebase-admin";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import * as crypto from "crypto";

admin.initializeApp();

const db = admin.firestore();
const LOCK_DURATION_MS = 5 * 60 * 1000; // 5 minutes
const MAX_OTP_ATTEMPTS_PER_DAY = 3;

// ── checkOtpRateLimit ─────────────────────────────────────────────────────────
// Called by the client BEFORE Firebase Auth's verifyPhoneNumber().
// Tracks OTP requests per phone number per UTC day in otpAttempts/{phone}.
// Rejects with resource-exhausted after MAX_OTP_ATTEMPTS_PER_DAY attempts.
//
// No auth required — user is not logged in yet when requesting OTP.
// Rate limit itself is the protection: keyed to phone number, not session.
// otpAttempts is CF-only write in Firestore rules — client cannot reset it.

export const checkOtpRateLimit = onCall(async (request) => {
  const { phone } = request.data as { phone: string };

  // Validate: must be E.164 format with +91 prefix and valid Indian mobile
  if (!phone || !/^\+91[6-9]\d{9}$/.test(phone)) {
    throw new HttpsError("invalid-argument", "Invalid phone number.");
  }

  // UTC date string as the daily reset key — "YYYY-MM-DD"
  const today = new Date().toISOString().split("T")[0];
  const docRef = db.collection("otpAttempts").doc(phone);

  await db.runTransaction(async (tx) => {
    const doc = await tx.get(docRef);

    if (!doc.exists || doc.data()!.date !== today) {
      // First attempt today (or ever) — create/reset counter
      tx.set(docRef, {
        phone,
        count: 1,
        date: today,
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const count = doc.data()!.count as number;
    if (count >= MAX_OTP_ATTEMPTS_PER_DAY) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many OTP requests. Please try again tomorrow."
      );
    }

    tx.update(docRef, {
      count: admin.firestore.FieldValue.increment(1),
      lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { allowed: true };
});

// ── Helper: deduplicate and validate slotIds ──────────────────────────────────
// Deduplication prevents: paying for 1 slot but passing ["slot1","slot1","slot1","slot1"]
// to inflate duration or bypass the max-slots check.
function validateSlotIds(slotIds: unknown): string[] {
  if (!Array.isArray(slotIds) || slotIds.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "slotIds must be a non-empty array."
    );
  }
  const unique = [...new Set(slotIds as string[])];
  if (unique.length > 4) {
    throw new HttpsError(
      "invalid-argument",
      "Maximum 4 slots (4 hours) per booking."
    );
  }
  return unique;
}

// ── lockSlot ──────────────────────────────────────────────────────────────────
// Locks one or more slots atomically for 5 minutes for this user.
// For multi-hour bookings, pass all slot IDs in the selected range.
// If any slot is booked or locked by another user, the entire transaction fails.

export const lockSlot = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const { turfId, slotIds: rawSlotIds } = request.data as {
    turfId: string;
    slotIds: string[];
  };

  if (!turfId) {
    throw new HttpsError("invalid-argument", "turfId is required.");
  }

  // Deduplicate before processing — prevents double-locking the same slot
  const slotIds = validateSlotIds(rawSlotIds);
  const uid = request.auth.uid;

  return db.runTransaction(async (tx) => {
    const slotRefs = slotIds.map((slotId) =>
      db.collection("turfs").doc(turfId).collection("slots").doc(slotId)
    );
    const slotDocs = await Promise.all(slotRefs.map((ref) => tx.get(ref)));

    const now = admin.firestore.Timestamp.now();
    const expirySeconds = Math.floor((Date.now() + LOCK_DURATION_MS) / 1000);
    const lockedUntilTs = new admin.firestore.Timestamp(expirySeconds, 0);

    for (const slot of slotDocs) {
      if (!slot.exists) {
        throw new HttpsError("not-found", `Slot ${slot.id} not found.`);
      }

      const data = slot.data()!;
      const lockedUntil = data.lockedUntil as admin.firestore.Timestamp | null;

      // Multi-court availability check
      const courtCount = (data.courtCount as number | undefined) ?? 1;
      const coachingReserved = (data.coachingReserved as number | undefined) ?? 0;
      const bookedCount = (data.bookedCount as number | undefined) ?? 0;
      const availableCount = courtCount - coachingReserved - bookedCount;

      if (data.isBooked || availableCount <= 0) {
        throw new HttpsError(
          "already-exists",
          "One or more slots are already fully booked."
        );
      }

      // Allow re-lock if already locked by this same user
      if (
        lockedUntil &&
        lockedUntil.toMillis() > now.toMillis() &&
        data.lockedBy !== uid
      ) {
        throw new HttpsError(
          "already-exists",
          "One or more slots are locked by another user. Try again in a few minutes."
        );
      }
    }

    for (const ref of slotRefs) {
      tx.update(ref, {
        lockedBy: uid,
        lockedUntil: lockedUntilTs,
      });
    }

    return { success: true, lockedUntilMs: expirySeconds * 1000 };
  });
});

// ── createRazorpayOrder ────────────────────────────────────────────────────────
// Creates a Razorpay order server-side. Amount is calculated from Firestore
// pricePerHour — the client NEVER controls the amount.
//
// Also stores a pendingOrders document so createBooking can verify:
//   1. This orderId was created by OUR server (not forged)
//   2. The turfId matches (prevents cross-turf price manipulation)
//   3. The amount matches (belt-and-suspenders check)
//
// Set secrets once:
//   firebase functions:secrets:set RAZORPAY_KEY_ID
//   firebase functions:secrets:set RAZORPAY_KEY_SECRET

export const createRazorpayOrder = onCall(
  { secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const {
      turfId,
      turfName,
      cityId,
      sport,
      slotIds: rawSlotIds,
      slotDate,
      slotStartTime,
      slotEndTime,
      receipt,
    } = request.data as {
      turfId: string;
      turfName: string;
      cityId: string;
      sport: string;
      slotIds: string[];
      slotDate: string;
      slotStartTime: string;
      slotEndTime: string;
      receipt: string;
    };

    if (!turfName?.trim() || !cityId?.trim() || !sport?.trim() ||
        !slotDate || !slotStartTime || !slotEndTime) {
      throw new HttpsError("invalid-argument", "Missing required booking metadata.");
    }

    if (!/^\d{4}-\d{2}-\d{2}$/.test(slotDate)) {
      throw new HttpsError("invalid-argument", "Invalid slotDate format.");
    }

    // Validate slotDate is within the allowed booking window:
    // not in the past, and not more than 7 days out (matches client UI).
    const slotDateObj = new Date(slotDate + "T00:00:00Z");
    const todayUtc = new Date();
    todayUtc.setUTCHours(0, 0, 0, 0);
    const maxDateUtc = new Date(todayUtc);
    maxDateUtc.setUTCDate(maxDateUtc.getUTCDate() + 7);

    if (slotDateObj < todayUtc) {
      throw new HttpsError("invalid-argument", "Cannot book slots in the past.");
    }
    if (slotDateObj > maxDateUtc) {
      throw new HttpsError("invalid-argument", "Bookings can only be made up to 7 days in advance.");
    }

    if (!turfId) {
      throw new HttpsError("invalid-argument", "turfId is required.");
    }

    // Deduplicate — prevents inflating amount by passing duplicate slot IDs
    const slotIds = validateSlotIds(rawSlotIds);
    const uid = request.auth.uid;

    // Recalculate amount server-side — never trust the client-sent amount.
    // This prevents paying ₹1 for a ₹1,000 slot.
    const turfDoc = await db.collection("turfs").doc(turfId).get();
    if (!turfDoc.exists) {
      throw new HttpsError("not-found", "Turf not found.");
    }
    const turfData = turfDoc.data()!;
    const pricePerHour = turfData.pricePerHour as number;
    if (!pricePerHour || pricePerHour <= 0) {
      throw new HttpsError("internal", "Invalid turf pricing.");
    }

    // Commission rate: read from turf doc, default 13%.
    // Change anytime in Firestore — no code deployment needed.
    const commissionRate = (turfData.commissionRate as number | undefined) ?? 0.13;

    const totalSlotPrice = Math.round(pricePerHour * slotIds.length);

    // Player pays 20% advance only. Balance paid cash at venue.
    const advanceAmount = Math.round(totalSlotPrice * 0.20);

    // Commission is taken from the advance.
    const commission = Math.round(totalSlotPrice * commissionRate);

    // What the owner receives digitally (advance minus our commission).
    // Owner collects the remaining balance (80%) in cash at venue.
    const ownerPayout = advanceAmount - commission;
    const balanceDueAtVenue = totalSlotPrice - advanceAmount;

    const amountInPaise = advanceAmount * 100;

    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_KEY_SECRET;

    if (!keyId || !keySecret) {
      throw new HttpsError("internal", "Payment configuration error.");
    }

    const credentials = Buffer.from(`${keyId}:${keySecret}`).toString("base64");

    // Null-safe receipt — fallback if client sends nothing
    const safeReceipt = (receipt || `tgo_${Date.now()}`).substring(0, 40);

    const response = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        Authorization: `Basic ${credentials}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: amountInPaise,
        currency: "INR",
        receipt: safeReceipt,
      }),
    });

    if (!response.ok) {
      const err = await response.text();
      console.error("Razorpay order creation failed:", err);
      throw new HttpsError("internal", "Failed to create payment order.");
    }

    const order = (await response.json()) as {
      id: string;
      amount: number;
      currency: string;
    };

    // Store pending order metadata for verification in createBooking and
    // razorpayWebhook. Stores full booking metadata so the webhook can create
    // the booking document without relying on the client app being alive.
    await db.collection("pendingOrders").doc(order.id).set({
      userId: uid,
      turfId,
      turfName: turfName.trim(),
      cityId: cityId.trim(),
      sport: sport.trim(),
      slotIds,
      slotDate,
      slotStartTime,
      slotEndTime,
      amountInPaise: order.amount,
      // Payment breakdown — stored so createBooking can verify & record
      totalSlotPrice,
      advanceAmount,
      commission,
      commissionRate,
      ownerPayout,
      balanceDueAtVenue,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      // 30-minute expiry — matches Razorpay order expiry
      expiresAt: new admin.firestore.Timestamp(
        Math.floor(Date.now() / 1000) + 30 * 60,
        0
      ),
    });

    // Return keyId so the client never needs to store it in the binary
    return {
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      keyId,
    };
  }
);

// ── createBooking ─────────────────────────────────────────────────────────────
// Called by the client after Razorpay fires EVENT_PAYMENT_SUCCESS.
// 1. Verifies orderId was created by OUR server for THIS turf — blocks cross-turf exploit.
// 2. Recalculates totalAmount server-side — client amount is never trusted.
// 3. Verifies Razorpay HMAC signature — blocks fake payment IDs.
// 4. Confirms all slots are still locked by this user — blocks race conditions.
// 5. Creates the booking document and marks all slots as booked atomically.

export const createBooking = onCall(
  { secrets: ["RAZORPAY_KEY_SECRET"] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const {
      turfId,
      turfName,
      cityId,
      slotIds: rawSlotIds,
      slotDate,
      slotStartTime,
      slotEndTime,
      sport,
      razorpayPaymentId,
      razorpayOrderId,
      razorpaySignature,
    } = request.data as {
      turfId: string;
      turfName: string;
      cityId: string;
      slotIds: string[];
      slotDate: string;
      slotStartTime: string;
      slotEndTime: string;
      sport: string;
      razorpayPaymentId: string;
      razorpayOrderId: string;
      razorpaySignature: string;
    };

    // ── Input validation ───────────────────────────────────────────────────
    if (
      !turfId || !turfName || !cityId || !slotDate ||
      !slotStartTime || !slotEndTime || !sport ||
      !razorpayPaymentId || !razorpayOrderId || !razorpaySignature
    ) {
      throw new HttpsError("invalid-argument", "Missing required booking fields.");
    }

    // Validate slotDate is a proper YYYY-MM-DD string
    if (!/^\d{4}-\d{2}-\d{2}$/.test(slotDate)) {
      throw new HttpsError("invalid-argument", "Invalid slotDate format.");
    }

    // Deduplicate slotIds
    const slotIds = validateSlotIds(rawSlotIds);
    const uid = request.auth.uid;

    // ── Verify pending order ──────────────────────────────────────────────
    // Confirms this orderId was created by OUR createRazorpayOrder CF
    // for this exact user and turf — blocks cross-turf price manipulation.
    const pendingOrderDoc = await db
      .collection("pendingOrders")
      .doc(razorpayOrderId)
      .get();

    if (!pendingOrderDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Order not found. Please start the booking again."
      );
    }

    const pendingOrder = pendingOrderDoc.data()!;

    if (pendingOrder.userId !== uid) {
      throw new HttpsError("permission-denied", "Order does not belong to this user.");
    }

    if (pendingOrder.turfId !== turfId) {
      console.error(
        `Cross-turf attempt: order turfId=${pendingOrder.turfId}, request turfId=${turfId}, uid=${uid}`
      );
      throw new HttpsError("invalid-argument", "Order turf mismatch.");
    }

    // ── Recalculate amounts server-side ───────────────────────────────────
    const turfDoc = await db.collection("turfs").doc(turfId).get();
    if (!turfDoc.exists) {
      throw new HttpsError("not-found", "Turf not found.");
    }
    const turfData = turfDoc.data()!;
    const pricePerHour = turfData.pricePerHour as number;
    if (!pricePerHour || pricePerHour <= 0) {
      throw new HttpsError("internal", "Invalid turf pricing.");
    }

    const commissionRate = (turfData.commissionRate as number | undefined) ?? 0.13;
    const totalSlotPrice = Math.round(pricePerHour * slotIds.length);
    const advancePaid = Math.round(totalSlotPrice * 0.20);
    const commission = Math.round(totalSlotPrice * commissionRate);
    const ownerPayout = advancePaid - commission;
    const balanceDueAtVenue = totalSlotPrice - advancePaid;

    const expectedAmountInPaise = advancePaid * 100;

    // Belt-and-suspenders: verify advance matches what was ordered
    if (pendingOrder.amountInPaise !== expectedAmountInPaise) {
      console.error(
        `Amount mismatch: ordered=${pendingOrder.amountInPaise}, expected=${expectedAmountInPaise}, uid=${uid}`
      );
      throw new HttpsError("invalid-argument", "Payment amount mismatch.");
    }

    // ── Verify Razorpay HMAC signature ─────────────────────────────────────
    // Without this, anyone could call this function with a fake paymentId
    // and get a confirmed booking without actually paying.
    const secret = process.env.RAZORPAY_KEY_SECRET;
    if (!secret) {
      throw new HttpsError("internal", "Payment configuration error.");
    }

    const expectedSignature = crypto
      .createHmac("sha256", secret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest("hex");

    if (expectedSignature !== razorpaySignature) {
      throw new HttpsError(
        "invalid-argument",
        "Payment verification failed. Invalid signature."
      );
    }

    // ── Create booking atomically ──────────────────────────────────────────
    const slotRefs = slotIds.map((slotId) =>
      db.collection("turfs").doc(turfId).collection("slots").doc(slotId)
    );
    const bookingRef = db.collection("bookings").doc();

    return db.runTransaction(async (tx) => {
      const slotDocs = await Promise.all(slotRefs.map((ref) => tx.get(ref)));
      const now = admin.firestore.Timestamp.now();

      for (const slot of slotDocs) {
        if (!slot.exists) {
          throw new HttpsError("not-found", `Slot ${slot.id} not found.`);
        }

        const slotData = slot.data()!;
        const lockedUntil =
          slotData.lockedUntil as admin.firestore.Timestamp | null;

        // Multi-court: check if any court is still available
        const slotCourtCount = (slotData.courtCount as number | undefined) ?? 1;
        const slotCoachingReserved = (slotData.coachingReserved as number | undefined) ?? 0;
        const slotBookedCount = (slotData.bookedCount as number | undefined) ?? 0;
        const slotAvailable = slotCourtCount - slotCoachingReserved - slotBookedCount;

        if (slotData.isBooked || slotAvailable <= 0) {
          throw new HttpsError(
            "already-exists",
            "A slot was just booked by someone else."
          );
        }

        // Slot must still be locked by this user
        if (
          !lockedUntil ||
          lockedUntil.toMillis() < now.toMillis() ||
          slotData.lockedBy !== uid
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Slot lock expired. Please select the slot again."
          );
        }
      }

      const refundWindowExpiry = new admin.firestore.Timestamp(
        now.seconds + 24 * 60 * 60,
        0
      );

      tx.set(bookingRef, {
        userId: uid,
        turfId,
        turfName,
        cityId,
        sport,
        slotDate,
        slotStartTime,
        slotEndTime,
        slotIds,
        totalSlotPrice,       // full slot price e.g. ₹1,000
        advancePaid,          // 20% paid now e.g. ₹200
        commission,           // TurfGo cut e.g. ₹130
        commissionRate,       // e.g. 0.13
        ownerPayout,          // sent to owner UPI e.g. ₹70
        balanceDueAtVenue,    // player pays at venue e.g. ₹800
        paymentId: razorpayPaymentId,
        razorpayOrderId,
        status: "confirmed",
        refundWindowExpiry,
        payoutStatus: "pending",
        cancelledAt: null,
        refundAmount: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update each slot atomically — increment bookedCount, only set isBooked
      // true when the last available court is filled.
      for (let i = 0; i < slotRefs.length; i++) {
        const sd = slotDocs[i].data()!;
        const cc = (sd.courtCount as number | undefined) ?? 1;
        const cr = (sd.coachingReserved as number | undefined) ?? 0;
        const bc = (sd.bookedCount as number | undefined) ?? 0;
        const willBeFull = bc + 1 >= cc - cr;
        tx.update(slotRefs[i], {
          bookedCount: admin.firestore.FieldValue.increment(1),
          bookingIds: admin.firestore.FieldValue.arrayUnion([bookingRef.id]),
          bookingId: bookingRef.id, // backward compat
          isBooked: willBeFull,
          lockedBy: null,
          lockedUntil: null,
        });
      }

      // Clean up pending order after successful booking
      tx.delete(db.collection("pendingOrders").doc(razorpayOrderId));

      return { bookingId: bookingRef.id };
    });
  }
);

// ── seedSlots ─────────────────────────────────────────────────────────────────
// DEV/EMULATOR ONLY — seeds slot documents for a turf so booking flow works.
// Admin-only. Call once per turf per date.
//
// Input:
//   turfId      — Firestore turf document ID
//   date        — 'YYYY-MM-DD'
//   sports      — string[] e.g. ['Football', 'Cricket']
//   pricePerHour — number
//   startHour   — number, default 6  (6 AM)
//   endHour     — number, default 22 (10 PM, last slot starts 21:00)

export const seedSlots = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  // Admin check
  const callerDoc = await db.collection("users").doc(request.auth.uid).get();
  if (callerDoc.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Admins only.");
  }

  const {
    turfId,
    date,
    sports,
    pricePerHour,
    startHour = 6,
    endHour = 22,
  } = request.data as {
    turfId: string;
    date: string;
    sports: string[];
    pricePerHour: number;
    startHour?: number;
    endHour?: number;
  };

  if (!turfId || !date || !sports?.length || !pricePerHour) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new HttpsError("invalid-argument", "date must be YYYY-MM-DD.");
  }

  // Read turf config for court counts and coaching schedule
  const turfDoc = await db.collection("turfs").doc(turfId).get();
  const turfData = turfDoc.data() ?? {};
  const courtCounts = (turfData.courtCounts ?? {}) as Record<string, number>;
  type CoachingEntry = { sport: string; fromHour: number; toHour: number; courts: number };
  const coachingSchedule = (turfData.coachingSchedule ?? []) as CoachingEntry[];

  const batch = db.batch();
  const slotsRef = db.collection("turfs").doc(turfId).collection("slots");
  let count = 0;

  for (const sport of sports) {
    const courtCount = courtCounts[sport] ?? 1;

    for (let hour = startHour; hour < endHour; hour++) {
      const coachingReserved = coachingSchedule
        .filter((c) => c.sport === sport && hour >= c.fromHour && hour < c.toHour)
        .reduce((sum, c) => sum + c.courts, 0);
      const clampedCoaching = Math.min(coachingReserved, courtCount);
      const startTime = `${String(hour).padStart(2, "0")}:00`;
      const endTime = `${String(hour + 1).padStart(2, "0")}:00`;
      const slotId = `${date}_${sport.toLowerCase()}_${startTime}`;
      const docRef = slotsRef.doc(slotId);
      batch.set(
        docRef,
        {
          date,
          startTime,
          endTime,
          sport,
          price: pricePerHour,
          courtCount,
          coachingReserved: clampedCoaching,
          bookedCount: 0,
          bookingIds: [],
          isBooked: clampedCoaching >= courtCount,
          bookingId: null,
          lockedUntil: null,
          lockedBy: null,
        },
        { merge: true } // skip if already exists
      );
      count++;
    }
  }

  await batch.commit();
  return { seeded: count, date, turfId };
});

// ── submitOwnerRequest ────────────────────────────────────────────────────────
// Submits a turf owner registration request.
//
// CRITICAL PATTERN — validate FIRST, write LAST:
//   All input validation happens before any Firestore write.
//   This prevents the lock-before-validate bug where a bad request
//   permanently locks a legitimate owner out of resubmitting.

export const submitOwnerRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const {
    turfName,
    address,
    cityId,
    sports,
    pricePerHour,
    phone,
    description,
  } = request.data as {
    turfName: string;
    address: string;
    cityId: string;
    sports: string[];
    pricePerHour: number;
    phone: string;
    description?: string;
  };

  // ── Step 1: Validate ALL inputs before touching Firestore ──────────────
  // Any failure here does NOT lock the user out — they can fix and resubmit.
  const missing: string[] = [];
  if (!turfName?.trim()) missing.push("turfName");
  if (!address?.trim()) missing.push("address");
  if (!cityId?.trim()) missing.push("cityId");
  if (!sports || sports.length === 0) missing.push("sports");
  if (!pricePerHour) missing.push("pricePerHour");
  if (!phone?.trim()) missing.push("phone");

  if (missing.length > 0) {
    throw new HttpsError(
      "invalid-argument",
      `Missing required fields: ${missing.join(", ")}`
    );
  }

  if (turfName.trim().length > 100) {
    throw new HttpsError(
      "invalid-argument",
      "Turf name must be 100 characters or less."
    );
  }

  if (!Array.isArray(sports) || sports.length > 10) {
    throw new HttpsError("invalid-argument", "Invalid sports list.");
  }

  if (pricePerHour < 100 || pricePerHour > 99999) {
    throw new HttpsError(
      "invalid-argument",
      "Price per hour must be between ₹100 and ₹99,999."
    );
  }

  if (!/^[6-9]\d{9}$/.test(phone)) {
    throw new HttpsError("invalid-argument", "Invalid Indian phone number.");
  }

  if (description && description.length > 500) {
    throw new HttpsError(
      "invalid-argument",
      "Description must be 500 characters or less."
    );
  }

  const uid = request.auth.uid;

  // ── Step 2: Check for existing pending request ─────────────────────────
  // Only runs AFTER validation passes — no wasted reads on bad input.
  const existingQuery = await db
    .collection("ownerRequests")
    .where("userId", "==", uid)
    .where("status", "==", "pending")
    .limit(1)
    .get();

  if (!existingQuery.empty) {
    throw new HttpsError(
      "already-exists",
      "You already have a pending owner request. Please wait for review."
    );
  }

  // ── Step 3: Write the request (all validation passed) ──────────────────
  const reqRef = db.collection("ownerRequests").doc();
  await reqRef.set({
    userId: uid,
    turfName: turfName.trim(),
    address: address.trim(),
    cityId: cityId.trim(),
    sports,
    pricePerHour,
    phone: phone.trim(),
    description: description?.trim() ?? "",
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    reviewedAt: null,
    rejectionReason: null,
  });

  return { requestId: reqRef.id };
});

// ── razorpayWebhook ───────────────────────────────────────────────────────────
// Server-to-server fallback: Razorpay calls this directly when payment.captured
// fires, bypassing the client app entirely.
//
// Handles the case where the app crashes / loses network after payment but
// before createBooking is called — ensures the booking is always created.
//
// Security:
//   - Verifies X-Razorpay-Signature using HMAC-SHA256 + webhook secret
//   - Idempotent: skips if booking for this orderId already exists
//   - Recalculates amount server-side — never trusts Razorpay event amount alone
//   - Returns 200 on all non-retryable errors to stop Razorpay retry loops
//
// Set secret once:
//   firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
//   (this is SEPARATE from RAZORPAY_KEY_SECRET — set it in Razorpay dashboard)

export const razorpayWebhook = onRequest(
  { secrets: ["RAZORPAY_WEBHOOK_SECRET"] },
  async (req, res) => {
    // Only accept POST
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // ── Verify Razorpay webhook signature ──────────────────────────────────
    // Uses raw body — must be compared before any JSON parsing alters it.
    const signature = req.headers["x-razorpay-signature"] as string | undefined;
    if (!signature) {
      console.warn("Webhook: missing X-Razorpay-Signature header");
      res.status(400).send("Missing signature");
      return;
    }

    const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;
    if (!webhookSecret) {
      console.error("Webhook: RAZORPAY_WEBHOOK_SECRET not configured");
      res.status(500).send("Configuration error");
      return;
    }

    const rawBody: Buffer = req.rawBody;
    const expectedSig = crypto
      .createHmac("sha256", webhookSecret)
      .update(rawBody)
      .digest("hex");

    if (expectedSig !== signature) {
      console.warn("Webhook: signature mismatch — possible spoofed request");
      res.status(400).send("Invalid signature");
      return;
    }

    // ── Parse and validate event ───────────────────────────────────────────
    const event = req.body as {
      event: string;
      payload?: {
        payment?: {
          entity?: {
            id?: string;
            order_id?: string;
            amount?: number;
          };
        };
      };
    };

    // Only handle payment.captured — ignore all other events
    if (event.event !== "payment.captured") {
      res.status(200).send("Event ignored");
      return;
    }

    const razorpayPaymentId = event.payload?.payment?.entity?.id;
    const razorpayOrderId = event.payload?.payment?.entity?.order_id;
    const capturedAmountInPaise = event.payload?.payment?.entity?.amount;

    if (!razorpayPaymentId || !razorpayOrderId || !capturedAmountInPaise) {
      console.error("Webhook: malformed payment.captured payload", event.payload);
      res.status(200).send("Malformed payload"); // 200 — no point retrying
      return;
    }

    // ── Idempotency check ──────────────────────────────────────────────────
    // createBooking (app path) may have already created this booking.
    // If so, return 200 immediately — nothing to do.
    const existingBooking = await db
      .collection("bookings")
      .where("razorpayOrderId", "==", razorpayOrderId)
      .limit(1)
      .get();

    if (!existingBooking.empty) {
      res.status(200).send("Already processed");
      return;
    }

    // ── Look up pending order ──────────────────────────────────────────────
    const pendingOrderDoc = await db
      .collection("pendingOrders")
      .doc(razorpayOrderId)
      .get();

    if (!pendingOrderDoc.exists) {
      // Order expired or never created — can't reconstruct booking safely.
      // Log for manual investigation; return 200 to stop Razorpay retries.
      console.error(
        `Webhook: pendingOrder missing for orderId=${razorpayOrderId} paymentId=${razorpayPaymentId}`
      );
      res.status(200).send("Pending order not found");
      return;
    }

    const pendingOrder = pendingOrderDoc.data()!;

    // Check order has not expired
    const now = admin.firestore.Timestamp.now();
    if (pendingOrder.expiresAt && pendingOrder.expiresAt.toMillis() < now.toMillis()) {
      console.error(
        `Webhook: pendingOrder expired for orderId=${razorpayOrderId}`
      );
      res.status(200).send("Order expired");
      return;
    }

    const {
      userId,
      turfId,
      turfName,
      cityId,
      sport,
      slotIds,
      slotDate,
      slotStartTime,
      slotEndTime,
    } = pendingOrder as {
      userId: string;
      turfId: string;
      turfName: string;
      cityId: string;
      sport: string;
      slotIds: string[];
      slotDate: string;
      slotStartTime: string;
      slotEndTime: string;
    };

    // ── Recalculate amount server-side ─────────────────────────────────────
    // Never trust the amount from the Razorpay event payload alone.
    const turfDoc = await db.collection("turfs").doc(turfId).get();
    if (!turfDoc.exists) {
      console.error(`Webhook: turf not found turfId=${turfId}`);
      res.status(200).send("Turf not found");
      return;
    }

    const webhookTurfData = turfDoc.data()!;
    const pricePerHour = webhookTurfData.pricePerHour as number;
    if (!pricePerHour || pricePerHour <= 0) {
      console.error(`Webhook: invalid pricePerHour for turfId=${turfId}`);
      res.status(200).send("Invalid turf pricing");
      return;
    }

    const webhookCommissionRate = (webhookTurfData.commissionRate as number | undefined) ?? 0.13;
    const webhookTotalSlotPrice = Math.round(pricePerHour * slotIds.length);
    const webhookAdvancePaid = Math.round(webhookTotalSlotPrice * 0.20);
    const webhookCommission = Math.round(webhookTotalSlotPrice * webhookCommissionRate);
    const webhookOwnerPayout = webhookAdvancePaid - webhookCommission;
    const webhookBalanceDueAtVenue = webhookTotalSlotPrice - webhookAdvancePaid;

    const totalAmount = webhookAdvancePaid; // what was actually charged
    const expectedAmountInPaise = webhookAdvancePaid * 100;

    // Belt-and-suspenders: captured amount must match what we calculated
    if (capturedAmountInPaise !== expectedAmountInPaise) {
      console.error(
        `Webhook: amount mismatch captured=${capturedAmountInPaise} expected=${expectedAmountInPaise} orderId=${razorpayOrderId}`
      );
      res.status(200).send("Amount mismatch");
      return;
    }

    // ── Create booking atomically ──────────────────────────────────────────
    // Slot lock check is SKIPPED on the webhook path — payment is confirmed
    // by Razorpay server-to-server. The lock may have expired during network
    // issues but the user has legitimately paid.
    // The isBooked check still protects against double-booking.
    const slotRefs = slotIds.map((slotId: string) =>
      db.collection("turfs").doc(turfId).collection("slots").doc(slotId)
    );
    const bookingRef = db.collection("bookings").doc();

    try {
      await db.runTransaction(async (tx) => {
        const slotDocs = await Promise.all(slotRefs.map((ref) => tx.get(ref)));

        for (const slot of slotDocs) {
          if (!slot.exists) {
            throw new Error(`Slot ${slot.id} not found`);
          }
          const sd = slot.data()!;
          const cc = (sd.courtCount as number | undefined) ?? 1;
          const cr = (sd.coachingReserved as number | undefined) ?? 0;
          const bc = (sd.bookedCount as number | undefined) ?? 0;
          if (sd.isBooked || cc - cr - bc <= 0) {
            throw new Error(`Slot ${slot.id} already booked`);
          }
        }

        const refundWindowExpiry = new admin.firestore.Timestamp(
          now.seconds + 24 * 60 * 60,
          0
        );

        tx.set(bookingRef, {
          userId,
          turfId,
          turfName,
          cityId,
          sport,
          slotDate,
          slotStartTime,
          slotEndTime,
          slotIds,
          totalSlotPrice: webhookTotalSlotPrice,
          advancePaid: webhookAdvancePaid,
          commission: webhookCommission,
          commissionRate: webhookCommissionRate,
          ownerPayout: webhookOwnerPayout,
          balanceDueAtVenue: webhookBalanceDueAtVenue,
          paymentId: razorpayPaymentId,
          razorpayOrderId,
          status: "confirmed",
          refundWindowExpiry,
          payoutStatus: "pending",
          cancelledAt: null,
          refundAmount: null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdVia: "webhook",
        });

        for (let i = 0; i < slotRefs.length; i++) {
          const sd = slotDocs[i].data()!;
          const cc = (sd.courtCount as number | undefined) ?? 1;
          const cr = (sd.coachingReserved as number | undefined) ?? 0;
          const bc = (sd.bookedCount as number | undefined) ?? 0;
          const willBeFull = bc + 1 >= cc - cr;
          tx.update(slotRefs[i], {
            bookedCount: admin.firestore.FieldValue.increment(1),
            bookingIds: admin.firestore.FieldValue.arrayUnion([bookingRef.id]),
            bookingId: bookingRef.id,
            isBooked: willBeFull,
            lockedBy: null,
            lockedUntil: null,
          });
        }

        // Clean up pending order
        tx.delete(db.collection("pendingOrders").doc(razorpayOrderId));
      });

      console.log(
        `Webhook: booking created bookingId=${bookingRef.id} orderId=${razorpayOrderId}`
      );
      res.status(200).send("Booking created");
    } catch (err) {
      // Return 500 so Razorpay retries — this was an unexpected server error
      console.error("Webhook: transaction failed", err);
      res.status(500).send("Booking creation failed");
    }
  }
);

// ── cancelBooking ─────────────────────────────────────────────────────────────
// Player-initiated cancellation.
//
// Refund policy:
//   • Cancelled > 24 h before slot start → full advance refund via Razorpay
//   • Cancelled ≤ 24 h before slot start → no refund (advance forfeited)
//
// Atomically:
//   1. Marks booking as 'cancelled'
//   2. Decrements bookedCount on every slot in booking.slotIds
//   3. Removes bookingId from slot.bookingIds array
//   4. Sets slot.isBooked = false (slot is now available again)
//
// After transaction: initiates Razorpay refund if eligible.
// Refund failure does NOT re-open the booking — it flags refundStatus='failed'
// for manual review in the admin dashboard.

export const cancelBooking = onCall(
  { secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }
    const uid = request.auth.uid;
    const { bookingId } = request.data as { bookingId: string };

    if (!bookingId || typeof bookingId !== "string") {
      throw new HttpsError("invalid-argument", "bookingId is required.");
    }

    const bookingRef = db.collection("bookings").doc(bookingId);
    let refundAmount = 0;
    let paymentId = "";

    await db.runTransaction(async (tx) => {
      const bookingDoc = await tx.get(bookingRef);
      if (!bookingDoc.exists) {
        throw new HttpsError("not-found", "Booking not found.");
      }

      const booking = bookingDoc.data()!;

      if (booking.userId !== uid) {
        throw new HttpsError("permission-denied", "Not your booking.");
      }

      if (booking.status !== "confirmed") {
        throw new HttpsError(
          "failed-precondition",
          `Booking is already ${booking.status}.`
        );
      }

      // Parse slot start in IST (UTC+5:30)
      const slotDateTime = new Date(
        `${booking.slotDate}T${booking.slotStartTime}:00+05:30`
      );
      const now = new Date();
      const hoursUntilSlot =
        (slotDateTime.getTime() - now.getTime()) / (1000 * 60 * 60);

      if (hoursUntilSlot < 0) {
        throw new HttpsError(
          "failed-precondition",
          "Cannot cancel a booking that has already started."
        );
      }

      // Refund policy: full advance refund only if > 24 h away
      const isRefundEligible = hoursUntilSlot > 24;
      refundAmount = isRefundEligible ? (booking.advancePaid as number) : 0;
      paymentId = (booking.paymentId as string) ?? "";

      // Free every slot covered by this booking
      const slotIds = (booking.slotIds as string[]) ?? [];
      const turfId = booking.turfId as string;

      for (const slotId of slotIds) {
        const slotRef = db
          .collection("turfs")
          .doc(turfId)
          .collection("slots")
          .doc(slotId);
        const slotDoc = await tx.get(slotRef);
        if (slotDoc.exists) {
          tx.update(slotRef, {
            bookedCount: admin.firestore.FieldValue.increment(-1),
            bookingIds: admin.firestore.FieldValue.arrayRemove(bookingId),
            isBooked: false, // at least one court is now free
            lockedBy: null,
            lockedUntil: null,
          });
        }
      }

      tx.update(bookingRef, {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        refundAmount,
        payoutStatus: "cancelled",
      });
    });

    // Initiate Razorpay refund outside the transaction (network call)
    if (refundAmount > 0 && paymentId) {
      try {
        const keyId = process.env.RAZORPAY_KEY_ID!;
        const keySecret = process.env.RAZORPAY_KEY_SECRET!;
        const authHeader = Buffer.from(`${keyId}:${keySecret}`).toString(
          "base64"
        );

        const refundRes = await fetch(
          `https://api.razorpay.com/v1/payments/${paymentId}/refund`,
          {
            method: "POST",
            headers: {
              Authorization: `Basic ${authHeader}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              amount: Math.round(refundAmount * 100), // paise
              notes: {
                bookingId,
                reason: "Player cancellation — within refund window",
              },
            }),
          }
        );

        if (!refundRes.ok) {
          const errText = await refundRes.text();
          console.error(
            `Refund API failed for bookingId=${bookingId}`,
            errText
          );
          // Don't re-throw — booking is cancelled. Flag for manual admin review.
          await bookingRef.update({
            refundStatus: "failed",
            refundError: errText,
          });
        } else {
          const refundData = (await refundRes.json()) as { id: string };
          await bookingRef.update({
            refundStatus: "initiated",
            razorpayRefundId: refundData.id,
          });
          console.log(
            `Refund initiated: bookingId=${bookingId} refundId=${refundData.id} amount=₹${refundAmount}`
          );
        }
      } catch (err) {
        // Network/parse error — booking already cancelled, refund needs manual retry
        console.error("Refund initiation error", err);
        await bookingRef.update({ refundStatus: "failed" });
      }
    }

    return {
      success: true,
      refundAmount,
      message:
        refundAmount > 0
          ? `Booking cancelled. ₹${refundAmount} will be refunded within 5–7 business days.`
          : "Booking cancelled. Cancellations within 24 hours of the slot are non-refundable.",
    };
  }
);
