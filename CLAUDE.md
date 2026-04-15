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
- Razorpay webhook must be implemented (endpoint: razorpayWebhook CF, already deployed)
- Upgrade Cloud Functions from Node 20 → Node 22 before 2026-10-30 (Node 20 deprecated)

## Known Bugs & Fixes (Hard-Won — Never Reintroduce)

### Cloud Run IAM — Gen 2 Functions Return 401
Firebase Gen 2 callable functions run on Cloud Run. After deploy, they default to
requiring auth at the infrastructure level. Fix: grant `allUsers` the `roles/run.invoker`
role on each Cloud Run service via the Google Cloud Console or REST API.
This must be done after EVERY initial deploy (re-deploys preserve it).

### Razorpay Secrets Have Trailing Newlines
When Firebase Secret Manager injects secrets as env vars in Cloud Run, they include a
trailing `\n`. Always `.trim()` when reading:
```typescript
const keyId = process.env.RAZORPAY_KEY_ID?.trim();
const keySecret = process.env.RAZORPAY_KEY_SECRET?.trim();
```

### functions/.env Conflicts With Secret Manager
If `functions/.env` defines `RAZORPAY_KEY_ID` or `RAZORPAY_KEY_SECRET` as plain env
vars AND the function declares them as secrets, Cloud Run deployment fails with:
"Secret environment variable overlaps non secret environment variable."
Fix: keep `functions/.env` empty of any key that's also in Secret Manager.

### TypeScript Build — Unused Variable
`functions/src/index.ts` line ~962 had `const totalAmount = webhookAdvancePaid;`
that was never used. TypeScript strict mode treats this as a build error. Remove it.
Run `npm --prefix functions run build` before every deploy to catch this.

### Receipt String RangeError
`'tgo_\${DateTime.now().millisecondsSinceEpoch}'.substring(0, 40)` throws RangeError
because the string is only 17 chars. Always guard: use the string as-is (it's under 40).

### OTP/Login Navigation Loop
Never call `context.pop()` from a non-top widget's listener — in GoRouter it always
pops the TOP route. After OTP verification, pop both OTP and login synchronously:
```dart
final router = GoRouter.of(context);
if (router.canPop()) router.pop(); // pop OTP
if (router.canPop()) router.pop(); // pop login
```
Do NOT use `ref.listen` in login_screen to auto-pop — it fires while OTP is on top
and pops OTP instead of login, causing a loop.

### Android Auto-Verification
The `verificationCompleted` callback in `verifyPhoneNumber` auto-signs in users on
Android without showing the OTP screen. This is a privacy issue. Always make it a no-op:
```dart
verificationCompleted: (PhoneAuthCredential credential) async {
  // Auto-verification disabled — users must always enter OTP manually.
},
```

## Navigation Rules

- Sign out → `context.go('/home')` — never `context.go('/login')`
- Unauthenticated users: only `/owner` and `/admin` routes are blocked — all browsing is public
- Login gate is at `slot_selection._proceed()` — not at router level
- After OTP: double-pop (OTP + login) synchronously so user returns directly to booking flow

## Business Context

- **Launch city:** Madurai (approx. 30 turfs in the city)
- **Expansion plan:** Trichy → Coimbatore → Chennai → other TN cities
- **Slot prices:** Vary per turf — never assume a fixed price
- **Commission:** Configurable per business decision — currently 8% per booking
- **Owner agreement:** Owners in Madurai have verbally agreed to commission model
- **Competition:** Hudle and Playo operate in metros — stay under the radar until 3+ cities
- **Test turf:** "Kavin's Turf" seeded in Firestore under `cities/city_madurai`
- **Razorpay:** Test mode keys in Firebase Secret Manager. Key ID: rzp_test_... (never hardcode)

## Current Status

| Item | Status |
|---|---|
| Firestore security rules | Deployed, production-grade |
| All 8 Cloud Functions | Deployed ✅ (Node 20, us-central1) |
| Cloud Run IAM | Fixed — allUsers:run.invoker on all 8 services ✅ |
| Firebase Blaze plan | Active ✅ |
| Razorpay | Test mode, keys in Secret Manager ✅ |
| Razorpay webhook | Deployed, NOT fully tested end-to-end |
| Guest browsing | Working — login only required at payment ✅ |
| Advance payment (20%) | Working — shown correctly in booking confirmation ✅ |
| App Check | Not configured |
| CI/CD | Not set up |
| Node 20 → 22 upgrade | Pending (deadline: 2026-10-30) |
| App icon | Still default Flutter icon |
