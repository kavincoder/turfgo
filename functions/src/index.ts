import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as crypto from "crypto";

admin.initializeApp();

const db = admin.firestore();
const LOCK_DURATION_MS = 5 * 60 * 1000; // 5 minutes

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

      if (data.isBooked) {
        throw new HttpsError(
          "already-exists",
          "One or more slots are already booked."
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

    const { turfId, slotIds: rawSlotIds, receipt } = request.data as {
      turfId: string;
      slotIds: string[];
      receipt: string;
    };

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
    const pricePerHour = turfDoc.data()!.pricePerHour as number;
    if (!pricePerHour || pricePerHour <= 0) {
      throw new HttpsError("internal", "Invalid turf pricing.");
    }
    const totalAmount = Math.round(pricePerHour * slotIds.length);
    const amountInPaise = totalAmount * 100;

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

    // Store pending order metadata for verification in createBooking.
    // This prevents cross-turf price manipulation:
    //   An attacker cannot create a ₹200 order for a cheap turf and use it
    //   to book a ₹1,000 slot on a different turf.
    await db.collection("pendingOrders").doc(order.id).set({
      userId: uid,
      turfId,
      slotIds,
      amountInPaise: order.amount,
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

    // ── Recalculate totalAmount server-side ────────────────────────────────
    const turfDoc = await db.collection("turfs").doc(turfId).get();
    if (!turfDoc.exists) {
      throw new HttpsError("not-found", "Turf not found.");
    }
    const pricePerHour = turfDoc.data()!.pricePerHour as number;
    if (!pricePerHour || pricePerHour <= 0) {
      throw new HttpsError("internal", "Invalid turf pricing.");
    }
    const totalAmount = Math.round(pricePerHour * slotIds.length);
    const expectedAmountInPaise = totalAmount * 100;

    // Belt-and-suspenders: verify amount matches what was ordered
    if (pendingOrder.amountInPaise !== expectedAmountInPaise) {
      console.error(
        `Amount mismatch: ordered=${pendingOrder.amountInPaise}, expected=${expectedAmountInPaise}, uid=${uid}`
      );
      throw new HttpsError("invalid-argument", "Payment amount mismatch.");
    }

    const advancePaid = totalAmount; // 100% advance

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

        if (slotData.isBooked) {
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
        totalAmount,
        advancePaid,
        paymentId: razorpayPaymentId,
        razorpayOrderId,
        status: "confirmed",
        refundWindowExpiry,
        payoutStatus: "pending",
        cancelledAt: null,
        refundAmount: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      for (const ref of slotRefs) {
        tx.update(ref, {
          isBooked: true,
          bookingId: bookingRef.id,
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
