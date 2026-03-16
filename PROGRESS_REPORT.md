# TurfGo — Development Progress Report
**Date:** March 15, 2026
**Developer:** Kavin
**Stack:** Flutter 3.x · Firebase · Riverpod · Razorpay (upcoming)

---

## Project Overview

TurfGo is a two-sided sports turf booking marketplace for Madurai — described as "BookMyShow for sports turfs." Players book football, cricket, and badminton turfs instantly. Owners receive automatic payments. All 30 Madurai turfs currently use phone calls for booking with zero digital competitors in the city.

---

## What Has Been Completed

### 1. Project Foundation
- Flutter project initialized for iOS, Android, Web, macOS, Linux, Windows
- Firebase connected and initialized (`firebase_options.dart`)
- `flutter_dotenv` set up — all secrets in `.env`, never hardcoded
- Portrait orientation locked
- Status bar styling configured
- `ProviderScope` set up for Riverpod state management

### 2. Theme & Design System
- Light theme implemented (`lib/core/theme.dart`)
  - Background: `#F8F9FA`
  - Card: `#FFFFFF`
  - Primary: `#00C96A` (green)
  - Text Primary: `#1A1A1A`
- Custom fonts integrated:
  - **DM Sans** — body text
  - **Bebas Neue** — display/branding
- `flutter_screenutil` configured with iPhone 16 Pro design size (393×852)
- `AppColors` and `AppTextStyles` constants defined

### 3. Data Models (6 models)
All models include `fromFirestore()` and `toMap()` methods:

| Model | Fields |
|-------|--------|
| `AppUser` | id, name, phone, cityId, role, referralCode, referredBy, createdAt |
| `Turf` | id, name, sports, pricePerHour, ownerId, cityId, photos, location, area, address, isActive, rating, amenities, openTime, closeTime |
| `Slot` | id, date, startTime, endTime, isBooked, bookingId, sport, price, lockedUntil, lockedBy |
| `Booking` | id, userId, turfId, cityId, sport, slotDate, slotStartTime, slotEndTime, totalAmount, advancePaid, paymentId, razorpayOrderId, status, refundWindowExpiry, payoutStatus, cancelledAt, refundAmount, createdAt |
| `Review` | id, userId, turfId, bookingId, rating, comment, createdAt, isVerified |
| `City` | id, name, state, status (live/coming_soon) |

### 4. Firebase Authentication (Phone OTP)
- `AuthRepository` created — all Firebase Auth calls abstracted from UI
- Real phone OTP login via Firebase Authentication
- On first login, Firestore user document auto-created
- Riverpod `authStateProvider` — real-time auth state stream
- `RouterNotifier` — triggers router refresh on login/logout
- Router redirect — logged-out users cannot access protected routes
- Logged-in users auto-skip login screen
- Test mode enabled in debug builds (`appVerificationDisabledForTesting`)
- Test phone numbers configured in Firebase Console

**Files:**
- `lib/data/repositories/auth_repository.dart`
- `lib/providers/auth_provider.dart`

### 5. Navigation (GoRouter)
- `routerProvider` — Riverpod-powered router
- Auth-aware redirect — protects all non-auth routes
- Routes: `/` (splash), `/login`, `/otp`, `/home`

### 6. Screens Built (10 screens)

#### Auth Flow
- **Splash Screen** — brand logo, auto-redirects based on auth state
- **Login Screen** — phone number entry with `+91` prefix, validation, loading state
- **OTP Screen** — 6-box OTP input, auto-advance, resend functionality, error handling

#### Main App
- **Home Screen** — green header with location detection, sport filter chips (All/Football/Cricket/Tennis/Badminton), real turf cards with shimmer skeleton loading
- **Explore Screen** — search bar, sport filter chips, turf list with shimmer skeleton
- **Turf Detail Screen** — photo header with gradient, turf info, amenity icons, mock reviews, Book Now bottom bar
- **Slot Selection Screen** — 7-day date picker, duration slider (1–6 hours), real-time slot grid (available/booked/selected states), sport selector for multi-sport turfs
- **Booking Confirmation Screen** — booking summary before payment
- **Bookings Screen** — user's booking history
- **Profile Screen** — user profile

#### Shell
- **Main Shell** — bottom navigation bar with Home, Explore, Bookings, Profile tabs

### 7. Firestore Repository Layer
Full repository pattern — Firebase never called directly from UI.

**TurfRepository** (`lib/data/repositories/turf_repository.dart`):
- `getTurfs(cityId)` — fetches all active turfs for a city
- `getTurf(turfId)` — fetches single turf by ID
- Inactive turfs filtered out — never exposed to users

**SlotRepository** (`lib/data/repositories/slot_repository.dart`):
- `getSlotsStream(turfId, date)` — real-time Firestore stream
- Slots update live as others book — no polling

**Riverpod Providers** (`lib/providers/turf_provider.dart`):
- `turfsProvider` — `FutureProvider.family` cached per cityId
- `turfDetailProvider` — `FutureProvider.family` cached per turfId
- `slotsProvider` — `StreamProvider.family` keyed by turfId + date

### 8. Firestore Database — Seeded
Firebase Firestore created and seeded with test data via a dev seed tool.

**Cities (3):**
- Madurai — `live`
- Chennai — `coming_soon`
- Coimbatore — `coming_soon`

**Turfs (3 in Madurai):**

| Turf | Sports | Price | Area | Hours |
|------|--------|-------|------|-------|
| KG Turf Arena | Football, Cricket | ₹800/hr | Kochadai | 06:00–22:00 |
| Madurai Sports Hub | Football, Badminton | ₹600/hr | Anna Nagar | 05:00–23:00 |
| Ace Badminton Club | Badminton | ₹400/hr | KK Nagar | 06:00–21:00 |

**Slots:** 7 days × hourly slots × sports per turf (~400+ slot documents). Some slots pre-marked as booked for realistic UI testing.

### 9. Security Standards Applied
- No Firebase keys exposed — all in `.env` via `flutter_dotenv`
- Repository pattern enforced — zero raw Firebase calls in UI layer
- Auth state checked on every route via router redirect
- `isActive` filter on turfs — disabled turfs never shown
- Firestore test mode (will be locked before launch)
- Server-side payment verification planned (webhook only)

### 10. Dev Tooling
- `lib/seed_main.dart` — standalone seed tool, run with `flutter run --target lib/seed_main.dart`. Idempotent, re-runnable anytime.

---

## Current App Flow (Working End-to-End)

```
Launch → Splash
    ↓
[Not logged in] → Login → OTP → Home
[Already logged in] → Home (auto)
    ↓
Home (real Firestore turfs with shimmer loading)
    ↓
Tap "Book Now" → Turf Detail (real data)
    ↓
Tap "Book Now" → Slot Selection (real-time slots, booked shown grey)
    ↓
Select slot → Booking Confirmation
```

---

## Packages Used

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Phone OTP authentication |
| `cloud_firestore` | Database |
| `firebase_storage` | File storage (upcoming) |
| `firebase_messaging` | Push notifications (upcoming) |
| `firebase_crashlytics` | Crash reporting (upcoming) |
| `flutter_riverpod` | State management |
| `go_router` | Navigation |
| `flutter_screenutil` | Responsive sizing |
| `cached_network_image` | Image caching |
| `shimmer` | Skeleton loading |
| `flutter_dotenv` | Environment variables |
| `geolocator` | User location |
| `geocoding` | Location to city name |
| `intl` | Date formatting |
| `razorpay_flutter` | Payments (upcoming) |

---

## What's Next

### Immediate Next Steps
1. **Payments — Razorpay integration**
   - Create Razorpay order via Firebase Cloud Function
   - Launch Razorpay payment sheet
   - Webhook for server-side payment verification
   - Slot booking written to Firestore only after payment confirmed

2. **Slot Locking** — 5-minute hold when user enters slot selection
3. **Bookings Screen** — wire to real Firestore booking data
4. **Profile Screen** — wire to real user data, allow name/city update
5. **Firestore Security Rules** — lock down before launch
6. **Firebase Cloud Functions** — payment webhook, payout logic
7. **FCM Push Notifications** — booking confirmations
8. **AiSensy WhatsApp** — owner notifications

---

## File Structure

```
lib/
├── core/
│   ├── constants.dart       # Colors, text styles
│   └── theme.dart           # App theme
├── data/
│   └── repositories/
│       ├── auth_repository.dart
│       ├── turf_repository.dart
│       └── slot_repository.dart
├── models/
│   ├── app_user.dart
│   ├── turf.dart
│   ├── slot.dart
│   ├── booking.dart
│   ├── review.dart
│   ├── city.dart
│   └── models.dart
├── providers/
│   ├── auth_provider.dart
│   └── turf_provider.dart
├── router/
│   └── app_router.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── otp_screen.dart
│   ├── splash/
│   │   └── splash_screen.dart
│   ├── shell/
│   │   └── main_shell.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── explore/
│   │   └── explore_screen.dart
│   ├── turf_detail/
│   │   └── turf_detail_screen.dart
│   ├── slot_selection/
│   │   └── slot_selection_screen.dart
│   ├── booking_confirmation/
│   │   └── booking_confirmation_screen.dart
│   ├── bookings/
│   │   └── bookings_screen.dart
│   └── profile/
│       └── profile_screen.dart
├── firebase_options.dart
├── main.dart
└── seed_main.dart           # Dev seed tool
```

---

*Report generated: March 15, 2026*
*TurfGo v1.0.0 — Pre-launch build*
