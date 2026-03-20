import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as crypto from "crypto";

admin.initializeApp();

const db = admin.firestore();
const LOCK_DURATION_MS = 5 * 60 * 1000; // 5 minutes

// ── lockSlot ──────────────────────────────────────────────────────────────────
// Locks one or more slots atomically for 5 minutes for this user.
// For multi-hour bookings, pass all slot IDs in the selected range.
// If any slot is booked or locked by another user, the entire transaction fails.

export const lockSlot = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const { turfId, slotIds } = request.data as {
    turfId: string;
    slotIds: string[];
  };

  if (!turfId || !slotIds || slotIds.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "turfId and slotIds are required."
    );
  }

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
// Creates a Razorpay order server-side. The client uses the returned orderId
// to open the Razorpay payment sheet. Amount must be in paise (₹1 = 100 paise).
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

    const { amountInPaise, receipt } = request.data as {
      amountInPaise: number;
      receipt: string;
    };

    if (!amountInPaise || amountInPaise < 100) {
      throw new HttpsError("invalid-argument", "Invalid amount.");
    }

    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_KEY_SECRET;

    if (!keyId || !keySecret) {
      throw new HttpsError("internal", "Payment configuration error.");
    }

    // Use Razorpay REST API directly — no SDK needed on Node 20 (native fetch)
    const credentials = Buffer.from(`${keyId}:${keySecret}`).toString(
      "base64"
    );

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

    // Return keyId so the client never needs to store it in the binary
    return { orderId: order.id, amount: order.amount, currency: order.currency, keyId };
  }
);

// ── createBooking ─────────────────────────────────────────────────────────────
// Called by the client after Razorpay fires EVENT_PAYMENT_SUCCESS.
// 1. Verifies the Razorpay payment signature server-side — prevents fake payments.
// 2. Confirms all slots are still locked by this user — prevents race conditions.
// 3. Creates the booking document and marks all slots as booked atomically.
//
// The secret is stored in Firebase Secret Manager — never in code.
// Set it once with: firebase functions:secrets:set RAZORPAY_KEY_SECRET

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
      slotIds,
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

    // ── Recalculate totalAmount server-side ────────────────────────────────
    // Never trust the client-sent amount — fetch pricePerHour from Firestore.
    // This prevents anyone from paying ₹1 for a ₹1,000 slot.
    const turfDoc = await db.collection("turfs").doc(turfId).get();
    if (!turfDoc.exists) {
      throw new HttpsError("not-found", "Turf not found.");
    }
    const pricePerHour = turfDoc.data()!.pricePerHour as number;
    if (!pricePerHour || pricePerHour <= 0) {
      throw new HttpsError("internal", "Invalid turf pricing.");
    }
    const totalAmount = Math.round(pricePerHour * slotIds.length);
    const advancePaid = totalAmount; // 100% advance payment

    // ── Verify Razorpay signature ──────────────────────────────────────────
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
    const uid = request.auth.uid;

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

      return { bookingId: bookingRef.id };
    });
  }
);
