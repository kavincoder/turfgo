import 'package:flutter/material.dart';

/// TurfGo brand colors — Light theme
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF00C96A);
  static const Color primaryLight = Color(0xFFE6FAF0);
  static const Color background = Color(0xFFF8F9FA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF0F1F3);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF1A1A1A);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color grey = Color(0xFF9CA3AF);
  static const Color greyLight = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFE5E7EB);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF22C55E);

  // Slot states
  static const Color slotAvailable = primary;
  static const Color slotBooked = Color(0xFFEF4444);
  static const Color slotPast = Color(0xFFD1D5DB);
  static const Color slotLocked = Color(0xFFF59E0B);
}

/// App-wide text styles using DM Sans (body) and Bebas Neue (display)
class AppTextStyles {
  AppTextStyles._();

  static const String bodyFont = 'DMSans';
  static const String displayFont = 'BebasNeue';
}

/// Commission and payment constants
class AppPayment {
  AppPayment._();

  static const double commissionRate = 0.08; // 8%
  static const double advanceRate = 0.20; // 20%
  static const int slotLockDurationMinutes = 5;
  static const int refundWindowHoursAfterSlot = 24;
  static const int maxOtpAttemptsPerDay = 3;
  static const int maxWrongCodeAttempts = 3;
  static const int otpExpiryMinutes = 5;
  static const int otpResendCooldownSeconds = 30;
}

/// Firestore collection paths
class FirestorePaths {
  FirestorePaths._();

  static const String cities = 'cities';
  static const String turfs = 'turfs';
  static const String users = 'users';
  static const String bookings = 'bookings';
  static const String payouts = 'payouts';
  static const String transactions = 'transactions';
  static const String reviews = 'reviews';
  static const String referrals = 'referrals';
  static const String waitlist = 'waitlist';
  static const String otpAttempts = 'otpAttempts';

  static String turfSlots(String turfId, String date) =>
      'turfs/$turfId/slots/$date';
}

/// Booking status values
class BookingStatus {
  BookingStatus._();

  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String noShow = 'no_show';
}

/// User roles
class UserRole {
  UserRole._();

  static const String player = 'player';
  static const String owner = 'owner';
  static const String admin = 'admin';
}

/// Sports supported
class Sports {
  Sports._();

  static const String football = 'Football';
  static const String cricket = 'Cricket';
  static const String badminton = 'Badminton';
  static const String tennis = 'Tennis';

  /// Sports available in phase 1 launch
  static const List<String> phase1 = [football, cricket];

  /// All supported sports (for turf registration)
  static const List<String> all = [football, cricket, badminton, tennis];

  /// Sports filter chips shown on home screen — includes 'All' as first option
  static const List<String> filterList = [
    'All',
    football,
    cricket,
    badminton,
    tennis,
  ];
}
