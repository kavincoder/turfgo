import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  // Semantic / chart palette — used across admin & owner dashboards
  static const Color primaryGradient = Color(0xFF00A857); // gradient end for profile card
  static const Color primaryDark = Color(0xFF1B4332); // deep green (photo bg)
  static const Color emerald = Color(0xFF059669);     // stat card — revenue
  static const Color blue = Color(0xFF2563EB);        // stat card — bookings
  static const Color purple = Color(0xFF7C3AED);      // stat card — users
  static const Color amber = Color(0xFFD97706);       // star / rating amber
  static const Color pink = Color(0xFFDB2777);        // stat card — referrals

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

  static const double commissionRate = 0.13; // 13%
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

/// Booking status values — single source of truth for status strings,
/// display labels, and badge colours.
class BookingStatus {
  BookingStatus._();

  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String noShow = 'no_show';

  /// Badge / chip colour for a given status string.
  static Color color(String status) {
    switch (status) {
      case confirmed:  return AppColors.primary;
      case pending:    return AppColors.warning;
      case cancelled:  return AppColors.error;
      case completed:  return AppColors.textSecondary;
      case noShow:     return AppColors.grey;
      default:         return AppColors.grey;
    }
  }

  /// Human-readable label for a given status string.
  static String label(String status) {
    switch (status) {
      case confirmed:  return 'Confirmed';
      case pending:    return 'Pending';
      case cancelled:  return 'Cancelled';
      case completed:  return 'Completed';
      case noShow:     return 'No Show';
      default:         return status;
    }
  }
}

/// User roles
class UserRole {
  UserRole._();

  static const String player = 'player';
  static const String owner = 'owner';
  static const String admin = 'admin';
}

/// Amenity utilities — single source of truth for amenity names and icons.
/// Used by owner registration, turf detail, and owner turf screens.
class AmenityUtils {
  AmenityUtils._();

  /// Ordered list of all supported amenities (used in registration step).
  static const List<String> all = [
    'Parking',
    'Washroom',
    'Drinking Water',
    'Changing Room',
    'First Aid',
    'Floodlights',
    'Seating Area',
    'Cafeteria',
    'WiFi',
  ];

  /// Icon for a given amenity name (case-insensitive).
  /// Falls back to a generic check icon for unknown values.
  static IconData icon(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'parking':        return Icons.local_parking_rounded;
      case 'washroom':       return Icons.wc_rounded;
      case 'drinking water': return Icons.water_drop_rounded;
      case 'changing room':  return Icons.checkroom_rounded;
      case 'first aid':      return Icons.medical_services_rounded;
      case 'floodlights':    return Icons.lightbulb_rounded;
      case 'seating area':   return Icons.event_seat_rounded;
      case 'cafeteria':      return Icons.restaurant_rounded;
      case 'wifi':           return Icons.wifi_rounded;
      default:               return Icons.check_circle_outline_rounded;
    }
  }
}

/// Price formatting
class AppFormat {
  AppFormat._();

  static final _priceFormat = NumberFormat('#,##,###', 'en_IN');

  /// Format a price as ₹1,000 (Indian numbering, no decimals)
  static String price(num amount) => '₹${_priceFormat.format(amount.toInt())}';
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
