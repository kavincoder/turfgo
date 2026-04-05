# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

TurfGo is a turf booking marketplace app — players discover and book sports turfs, owners manage their listings, admins oversee the platform. Launching in Madurai first, then expanding across Tamil Nadu.

- **Stack:** Flutter (Dart ^3.8.1) + Firebase (Firestore, Auth, Storage) + Cloud Functions (TypeScript, Node 20, v2) + Razorpay payments
- **State management:** Riverpod + repository pattern
- **Navigation:** GoRouter only — never use Navigator.push directly
- **Roles:** player, owner, admin (use UserRole constants, never magic strings)
- **Version:** 1.0.0+1

## Architecture

- All date/time/formatting → `lib/core/date_utils.dart` (TurfDateUtils)
- All colors → `lib/core/colors.dart` (AppColors)
- All constants (roles, sports, booking status) → `lib/core/constants.dart`
- Amenity icons → `lib/core/amenity_utils.dart` (AmenityUtils)
- Provider → Repository → Firestore (never call Firestore directly from widgets)
- Cloud Functions are the ONLY place bookings, slots, transactions, and payouts are written — never allow direct client writes to these collections

## Common Commands

- **Run the app:** `flutter run`
- **Run tests:** `flutter test`
- **Analyze code:** `flutter analyze`
- **Get dependencies:** `flutter pub get`
- **Format code:** `dart format .`
- **Deploy rules:** `firebase deploy --only firestore:rules`
- **Deploy functions:** `firebase deploy --only functions`
- **Build functions:** `npm --prefix functions run build`

## Security — Non-Negotiable Rules

These are hard rules. Never violate them regardless of convenience.

### API Keys & Secrets
- Razorpay `KEY_ID` and `KEY_SECRET` live in **Firebase Secret Manager only** — never in code, `.env` files, logs, or comments
- Never log payment IDs, order IDs, or signatures to console in production
- Never commit any file containing real API keys
- Firebase config (`firebase_options.dart`) is gitignored — never commit it

### Cloud Functions
- Every CF must check `request.auth` first — throw `unauthenticated` immediately if null
- Never trust `totalAmount` or `advancePaid` from the client — always recalculate from Firestore `pricePerHour` server-side
- Always verify Razorpay HMAC signature before creating a booking
- Slot lock must be verified inside the same transaction as booking creation
- Rate limiting must be implemented on auth-related functions (OTP, registration)
- All CF input must be validated — reject missing fields with `invalid-argument`
- Never expose internal error details to the client — log server-side, return generic message to client

### Firestore Rules
- Rules are production-grade and deployed — never loosen them
- `bookings`, `slots`, `transactions`, `payouts`, `otpAttempts`, `referrals` are CF-only writes (`allow write: if false`)
- Role escalation is blocked at both create and update on the `users` collection
- Catch-all deny is in place — any unlisted collection is fully locked by default
- Never add `allow write: if isAuth()` to any sensitive collection

### Client-Side
- Never use magic strings for roles — always use `UserRole.player`, `UserRole.owner`, `UserRole.admin`
- Never use magic strings for booking status — always use `BookingStatus` constants
- Never silent-catch errors — always `catch (e, st) { debugPrint(...) }`
- Phone validation: `RegExp(r'^[6-9]\d{9}$')` — never skip this

### Before Public Launch
- Firebase App Check must be configured
- Razorpay webhook must be implemented
- All 3 critical CF bugs must be fixed (totalAmount recalculation, receipt null crash, submitOwnerRequest lock bug)

## Business Context

- **Launch city:** Madurai (approx. 30 turfs in the city)
- **Expansion plan:** Trichy → Coimbatore → Chennai → other TN cities
- **Slot prices:** Vary per turf — never assume a fixed price
- **Commission:** Configurable per business decision — currently 8% per booking
- **Owner agreement:** Owners in Madurai have verbally agreed to commission model
- **Competition:** Hudle and Playo operate in metros — stay under the radar until 3+ cities

## Current Status

| Item | Status |
|---|---|
| Firestore security rules | Deployed and production-grade |
| Cloud Functions (lockSlot, createRazorpayOrder, createBooking) | Written, NOT deployed |
| Firebase Blaze plan | Pending activation |
| Razorpay | Test mode only, not verified |
| Razorpay webhook | Not implemented |
| App Check | Not configured |
| CI/CD | Not set up |
