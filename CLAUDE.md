# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.
Read this entire file before writing any code. Every rule here exists for a reason.

---

## Project Overview

**TurfGo** is a sports turf booking marketplace app. Players discover and book sports turfs, owners manage their listings, and admins oversee the platform. Launching in Madurai first, then expanding across Tamil Nadu.

- **Stack:** Flutter (Dart ^3.8.1) + Firebase (Firestore, Auth, Storage, Crashlytics, App Check) + Cloud Functions (TypeScript, Node 20, v2) + Razorpay payments
- **State management:** Riverpod 2.x + repository pattern
- **Navigation:** GoRouter only — never use `Navigator.push` directly
- **Roles:** `player`, `owner`, `admin` — use `UserRole` constants, never magic strings
- **Version:** 1.0.0+1 (update build number on every release)
- **Platforms:** iOS + Android, portrait-locked

---

## Architecture — Hard Rules

### Data flow
```
Widget → Provider (Riverpod) → Repository → Firestore / Cloud Function
```
- Never call Firestore directly from a widget or screen
- Never call Cloud Functions directly from a widget — go through `payment_repository.dart` or the relevant repository
- Providers are the only state layer — no `setState` in screens that deal with server data

### Core utilities — always use these, never duplicate
| What you need | Where it lives |
|---|---|
| Date/time/slot formatting | `lib/core/date_utils.dart` — `TurfDateUtils` |
| Colors | `lib/core/constants.dart` — `AppColors` |
| Text styles | `lib/core/constants.dart` — `AppTextStyles` |
| Price formatting | `lib/core/constants.dart` — `AppFormat.price(amount)` |
| Payment constants | `lib/core/constants.dart` — `AppPayment` |
| Amenity icons and labels | `lib/core/amenity_utils.dart` — `AmenityUtils` |
| Sport labels and emojis | `lib/core/date_utils.dart` — `TurfDateUtils.sportEmoji()` |
| Role constants | `lib/core/constants.dart` — `UserRole` |
| Booking status constants | `lib/core/constants.dart` — `BookingStatus` |

### What writes where
- `bookings`, `slots`, `transactions`, `payouts`, `otpAttempts`, `pendingOrders`, `referrals` — **Cloud Functions only**. Never write to these from the client under any circumstances.
- `turfs` (limited fields) — owner can update `name`, `area`, `address`, `sports`, `amenities`, `openTime`, `closeTime` via direct Firestore write. Cannot change `pricePerHour`, `ownerId`, `cityId`, `rating`, `isActive`.
- `users` — user can update own `name`, `cityId` only. Cannot change `role` or `phoneNumber`.
- `ownerRequests` — written by `submitOwnerRequest()` Cloud Function only.

---

## Common Commands

```bash
# Run app against real Firebase
flutter run

# Run app against local emulator
flutter run --dart-define=USE_EMULATOR=true

# Lint check
flutter analyze

# Run tests
flutter test

# Format all Dart code
dart format .

# Install Flutter dependencies
flutter pub get

# Build Cloud Functions (TypeScript → JavaScript)
npm --prefix functions run build

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Firestore indexes
firebase deploy --only firestore:indexes

# Deploy Cloud Functions
firebase deploy --only functions

# Deploy everything
firebase deploy

# Start local emulator
firebase emulators:start
```

---

## Security — Non-Negotiable Rules

These rules are absolute. Never violate them for convenience, speed, or any other reason.
If a task would require breaking one of these rules, stop and explain why instead of proceeding.

### 1. Secrets and API Keys

- **Razorpay `KEY_ID`, `KEY_SECRET`, `WEBHOOK_SECRET`** live in Firebase Secret Manager only — never in source code, never in `.env` files committed to git, never in logs, never in comments
- `functions/.secret.local` is gitignored and is used only for local emulator development with test keys
- `lib/firebase_options.dart` — Firebase API keys here are public client identifiers (same as a Google Maps API key in a web app). They are safe in source and safe in the binary. Do not panic about them.
- Never add any real secret to any file that is or could be committed to git
- Never log `paymentId`, `orderId`, `signature`, `KEY_SECRET`, or `WEBHOOK_SECRET` to console — not even in debug builds

### 2. Git Commit Safety — MANDATORY PRE-COMMIT CHECKLIST

Before every `git add` + `git commit`, Claude MUST verify none of the following are being staged:

| File / Pattern | Why it must never be committed |
|---|---|
| `.env`, `.env.*`, `*.env` | Contains secrets / API keys |
| `functions/.secret.local` | Razorpay test credentials |
| `GoogleService-Info.plist` | Firebase iOS config with private API key |
| `google-services.json` | Firebase Android config with private API key |
| `*.p8`, `*.p12`, `*.pem`, `*.key` | Apple / SSL private keys |
| `serviceAccountKey*.json` | Firebase admin SDK private key — full DB access |
| `*.keystore`, `*.jks` | Android signing keys |
| `android/key.properties` | Android signing credentials |
| Any file containing `KEY_SECRET`, `WEBHOOK_SECRET`, or `password` as a hardcoded string | Raw credentials in code |

**How to check before committing:**
```bash
# See exactly what is staged before committing
git diff --cached --name-only

# Check staged content for secrets
git diff --cached | grep -iE "(key_secret|webhook_secret|password\s*=|api_key\s*=)"
```

If any of the above are found — **stop immediately, do not commit, tell Kavin.**

Only commit Dart/Flutter source files, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `firestore.rules`, `firestore.indexes.json`, `firebase.json`, and `functions/src/*.ts`. When in doubt, don't stage it.

### 3. Cloud Functions — Every Function Must Follow These Rules

- Check `request.auth` first — throw `functions.https.HttpsError('unauthenticated', ...)` immediately if null. No exceptions.
- Never trust any amount, price, or total from the client. Always recalculate from Firestore `pricePerHour` server-side.
- Always verify Razorpay HMAC-SHA256 signature before creating a booking: `sha256Hmac(orderId + '|' + paymentId, KEY_SECRET)`
- Verify slot locks inside the same Firestore transaction as booking creation — never as separate reads
- Validate all input fields. Reject missing or malformed fields with `invalid-argument` before touching Firestore
- Never expose internal error messages to the client — `console.error()` server-side, return a generic message to the client
- Rate limit all auth-related functions — OTP is 3 attempts per phone per UTC day (atomic Firestore transaction)
- All financial operations must be idempotent — check if a booking already exists for an orderId before creating one

### 4. Firestore Rules

- Rules are production-grade. Never loosen them.
- The catch-all deny (`/{document=**} → allow read, write: if false`) must always remain at the bottom
- Never add `allow write: if isAuth()` to any collection that holds financial or role data
- `bookings`, `slots`, `transactions`, `payouts`, `otpAttempts`, `referrals`, `pendingOrders` are locked to Cloud Functions: `allow write: if false`
- Role escalation is blocked at both create (`role == 'player'`) and update (no `role` field allowed) on `users`
- An owner cannot change `pricePerHour`, `ownerId`, `cityId`, `rating`, or `isActive` on their own turf

### 5. Client-Side Rules

- Never use magic strings for roles — always `UserRole.player`, `UserRole.owner`, `UserRole.admin`
- Never use magic strings for booking status — always `BookingStatus.confirmed`, `BookingStatus.cancelled`, etc.
- Never silent-catch errors — always `catch (e, st) { debugPrint('Context: $e\n$st'); }`
- Phone number validation before any OTP call: `RegExp(r'^[6-9]\d{9}$')` — 10 digits, starts 6–9
- Never store Razorpay credentials on the client — the app never holds `KEY_SECRET`
- Never bypass App Check in production builds

### 6. Before Any Real User Touches the App

These must all be true before exposing the app to anyone outside development:
- [ ] Firebase Blaze plan active and Cloud Functions deployed
- [ ] Razorpay webhook URL registered in Razorpay dashboard
- [ ] Firebase App Check enforcement enabled in Firebase Console
- [ ] Real support phone number replacing all placeholder numbers
- [ ] iOS bundle ID updated from `com.example.turfgo`
- [ ] Crashlytics initialised in `main.dart`
- [ ] Upgrade Cloud Functions from Node 20 → Node 22 before 2026-10-30 (Node 20 deprecated)

---

## Payment Flow Reference

Understanding this is required before touching any payment-related code.

```
1. lockSlot()  ← Firestore transaction
   - Checks: slot.isBooked == false, slot.lockedUntil < now (or lockedBy == userId)
   - Sets: lockedBy=userId, lockedUntil=now+5min
   - Max 4 slots per booking

2. createRazorpayOrder()  ← Calls Razorpay API
   - Recalculates amount: pricePerHour * slotCount (from Firestore, not client)
   - Validates slotDate: not in past, within 7 days
   - Creates pendingOrders doc (30-min expiry)
   - Returns orderId + keyId to client

3. Razorpay Flutter SDK  ← Client-side only
   - Player completes payment
   - Returns: orderId, paymentId, signature

4. createBooking()  ← Firestore transaction
   - Re-verifies slot lock (lockedBy == userId, lockedUntil > now)
   - Verifies HMAC-SHA256: sha256(orderId|paymentId, KEY_SECRET) == signature
   - Recalculates amount server-side (third verification)
   - Creates booking, marks slots isBooked=true, deletes pendingOrder

5. razorpayWebhook()  ← Backup path
   - Triggered by Razorpay on payment.captured
   - Verifies X-Razorpay-Signature via HMAC-SHA256 on raw body
   - Idempotency: skips if booking already exists for orderId
   - Creates booking if createBooking() was missed (network drop, app crash)
```

---

## Firestore Collections Reference

| Collection | Purpose | Who Reads | Who Writes |
|---|---|---|---|
| `users/{uid}` | User profile + role | Self, admin | Self (name/cityId), CF (role on upgrade) |
| `cities/{id}` | City config | All auth | Admin |
| `turfs/{id}` | Turf listings | All auth | Admin, owner (limited fields) |
| `turfs/{id}/slots/{id}` | 30-min slot availability | All auth | CFs only |
| `bookings/{id}` | Booking records | Player + owner + admin | CFs only (cancel: player) |
| `reviews/{id}` | Turf reviews | All auth | Auth user create (admin update/delete) |
| `transactions/{id}` | Payment records | Self + admin | CFs only |
| `payouts/{id}` | Owner payout records | Owner + admin | CFs only |
| `otpAttempts/{phone}` | OTP rate limit tracker | — | CFs only |
| `pendingOrders/{id}` | In-flight payment state | Self | CFs only |
| `ownerRequests/{id}` | Turf owner applications | Self + admin | CFs only |
| `referrals/{id}` | Referral tracking | Self | CFs only |
| `waitlist/{id}` | Pre-launch waitlist | Admin | Public create |

---

## UI / UX Rules

- Use `flutter_screenutil` for all dimensions and font sizes — `18.sp`, `16.h`, `20.w`
- Use `AppColors.*` for all colors — never hardcode hex values
- Use `AppTextStyles.*` for text — never hardcode `TextStyle` inline in screens
- Use `AppFormat.price(amount)` for all rupee amounts — outputs `₹1,00,000` (Indian numbering)
- Loading states: use `Shimmer` widget from the `shimmer` package for list skeletons
- Error states: always show a user-readable message — never show raw exception text
- Empty states: every list screen must have an empty state with an icon and descriptive text
- All modals: use `showModalBottomSheet` for detail views, `showDialog` for confirmations
- Back navigation: every screen must have a way back — never strand the user

---

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

---

## Navigation Rules

- Sign out → `context.go('/home')` — never `context.go('/login')`
- Unauthenticated users: only `/owner` and `/admin` routes are blocked — all browsing is public
- Login gate is at `slot_selection._proceed()` — not at router level
- After OTP: double-pop (OTP + login) synchronously so user returns directly to booking flow

---

## Known Issues and Active Constraints

### Not Yet Built (Do Not Mark as Complete)
- Self-serve booking cancellation (currently shows WhatsApp placeholder)
- Push notifications (firebase_messaging imported, no logic implemented)
- Reviews write path (model + provider exist, no submit UI)
- Payout flow for owners (Firestore rules define the collection, nothing else)
- City selector for players
- Turf photo upload for owners (image_picker imported, not used)
- Referral system (Firestore rules exist, no code)

### Placeholder Values That Must Be Replaced Before Launch
- Support phone: `+91 98765 43210` — appears in `profile_screen.dart` and `bookings_screen.dart`
- iOS bundle ID: `com.example.turfgo` — must change in Xcode before App Store submission
- Android application ID: `com.example.turfgo` — must change in `android/app/build.gradle`

---

## Business Context

- **Launch city:** Madurai (~40 turfs, targeting 25–30 onboarded)
- **Expansion plan:** Trichy → Coimbatore → Chennai → other Tamil Nadu cities
- **Commission:** 8% per booking (`AppPayment.commissionRate`)
- **Advance payment:** 20% of total (`AppPayment.advanceRate`)
- **Slot duration:** 30 minutes each
- **Max slots per booking:** 4 (2 hours max)
- **Booking window:** Up to 7 days in advance
- **Slot lock:** 5 minutes (expires automatically if payment not completed)
- **Sports Phase 1:** Football, Cricket
- **Sports Phase 2:** Badminton, Tennis (defined in constants, not yet in owner onboarding UI)
- **Competitor awareness:** Playo operates in metros — stay under the radar until 3+ cities
- **Pricing:** Varies per turf — never assume a fixed price or hardcode one
- **Test turf:** "Kavin's Turf" seeded in Firestore under `cities/city_madurai`
- **Razorpay:** Test mode keys in Firebase Secret Manager. Key ID: rzp_test_... (never hardcode)

---

## Current Status (as of March 2026)

| Item | Status |
|---|---|
| Flutter app UI (player, owner, admin) | Complete |
| Firestore security rules | Deployed, production-grade |
| All 8 Cloud Functions | Deployed ✅ (Node 20, us-central1) |
| Cloud Run IAM | Fixed — allUsers:run.invoker on all 8 services ✅ |
| Firebase Blaze plan | Active ✅ |
| Razorpay | Test mode, keys in Secret Manager ✅ |
| Razorpay webhook | Deployed, NOT fully tested end-to-end |
| OTP rate limiting | Deployed in CF ✅ |
| Guest browsing | Working — login only required at payment ✅ |
| Advance payment (20%) | Working — shown correctly in booking confirmation ✅ |
| Firebase App Check | Configured in code, enforcement NOT enabled in Firebase Console |
| Firebase Crashlytics | Imported in pubspec, NOT initialised in main.dart |
| Firebase Analytics | NOT configured |
| Firebase Local Emulator | Configured and working (`--dart-define=USE_EMULATOR=true`) |
| Owner turf edit screen | Complete (`owner_turf_edit_screen.dart`) |
| Booking detail sheet | Complete (tappable cards, cancel dialog) |
| Price formatting | Complete (AppFormat.price, Indian numbering across all screens) |
| CI/CD | Not set up |
| Node 20 → 22 upgrade | Pending (deadline: 2026-10-30) |
| App icon | Still default Flutter icon |
| iOS bundle ID | `com.example.turfgo` — placeholder |
| Android application ID | `com.example.turfgo` — placeholder |
| README.md | Updated and complete |
| Self-serve cancellation | NOT built |
| Payout flow | NOT built |
| Push notifications | NOT built |
| Reviews write path | NOT built |
