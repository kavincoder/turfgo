import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as crypto from "crypto";

admin.initializeApp();

const db = admin.firestore();
const LOCK_DURATION_MS = 5 * 60 * 1000; // 5 minutes

// ── lockSlot ──────────────────────────────────────────────────────────────────
// Called by the client when a user selects a slot, before payment begins.
// Locks the slot for 5 minutes for this user. If already locked by another
// user, returns an error so the client can show "slot just taken" UI.

export const lockSlot = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const { turfId, slotId } = request.data as {
    turfId: string;
    slotId: string;
  };

  if (!turfId || !slotId) {
    throw new HttpsError(
      "invalid-argument",
      "turfId and slotId are required."
    );
  }

  const uid = request.auth.uid;
  const slotRef = db
    .collection("turfs")
    .doc(turfId)
    .collection("slots")
    .doc(slotId);

  return db.runTransaction(async (tx) => {
    const slot = await tx.get(slotRef);

    if (!slot.exists) {
      throw new HttpsError("not-found", "Slot not found.");
    }

    const data = slot.data()!;
    const now = admin.firestore.Timestamp.now();
    const lockedUntil = data.lockedUntil as admin.firestore.Timestamp | null;

    if (data.isBooked) {
      throw new HttpsError("already-exists", "Slot is already booked.");
    }

    // Allow re-lock if already locked by this same user
    if (
      lockedUntil &&
      lockedUntil.toMillis() > now.toMillis() &&
      data.lockedBy !== uid
    ) {
      throw new HttpsError(
        "already-exists",
        "Slot is locked by another user. Try again in a few minutes."
      );
    }

    const expirySeconds = Math.floor((Date.now() + LOCK_DURATION_MS) / 1000);

    tx.update(slotRef, {
      lockedBy: uid,
      lockedUntil: new admin.firestore.Timestamp(expirySeconds, 0),
    });

    return { success: true, lockedUntilMs: expirySeconds * 1000 };
  });
});

// ── createBooking ─────────────────────────────────────────────────────────────
// Called after a successful Razorpay payment.
// 1. Verifies the Razorpay payment signature (prevents fake payment bypass).
// 2. Confirms the slot is still locked by this user (prevents double booking).
// 3. Creates the booking document and marks the slot as booked atomically.
//
// The Razorpay secret is stored in Firebase Secret Manager — never in code.
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
      slotId,
      slotDate,
      slotStartTime,
      slotEndTime,
      sport,
      totalAmount,
      advancePaid,
      razorpayPaymentId,
      razorpayOrderId,
      razorpaySignature,
    } = request.data as {
      turfId: string;
      turfName: string;
      cityId: string;
      slotId: string;
      slotDate: string;
      slotStartTime: string;
      slotEndTime: string;
      sport: string;
      totalAmount: number;
      advancePaid: number;
      razorpayPaymentId: string;
      razorpayOrderId: string;
      razorpaySignature: string;
    };

    // ── Verify Razorpay signature ──────────────────────────────────────────
    // Without this check, anyone could call this function with a fake paymentId
    // and get a confirmed booking without paying.
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
    const slotRef = db
      .collection("turfs")
      .doc(turfId)
      .collection("slots")
      .doc(slotId);
    const bookingRef = db.collection("bookings").doc();

    return db.runTransaction(async (tx) => {
      const slot = await tx.get(slotRef);

      if (!slot.exists) {
        throw new HttpsError("not-found", "Slot not found.");
      }

      const slotData = slot.data()!;
      const now = admin.firestore.Timestamp.now();
      const lockedUntil =
        slotData.lockedUntil as admin.firestore.Timestamp | null;

      if (slotData.isBooked) {
        throw new HttpsError(
          "already-exists",
          "Slot was just booked by someone else."
        );
      }

      // Slot must still be locked by this user — prevents race conditions
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

      tx.update(slotRef, {
        isBooked: true,
        bookingId: bookingRef.id,
        lockedBy: null,
        lockedUntil: null,
      });

      return { bookingId: bookingRef.id };
    });
  }
);
