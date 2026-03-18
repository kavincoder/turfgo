import 'package:intl/intl.dart';

/// Shared date and time formatting utilities used across screens.
/// Single source of truth — no more copy-pasted formatters.
class TurfDateUtils {
  TurfDateUtils._();

  /// Returns today's date as 'YYYY-MM-DD'.
  static String todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Formats a DateTime as 'YYYY-MM-DD'.
  static String toDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Formats a 'YYYY-MM-DD' string to a human-readable date like 'Mon, 18 Mar 2026'.
  /// Returns the raw string if parsing fails.
  static String formatDate(String dateStr) {
    try {
      return DateFormat('EEE, d MMM yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  /// Formats a 'YYYY-MM-DD' string to a longer format like 'Monday, Mar 18 2026'.
  static String formatDateLong(String dateStr) {
    try {
      return DateFormat('EEEE, MMM d yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  /// Converts a 24-hour time string like '14:00' to '2:00 PM'.
  static String formatHour(String time24) {
    try {
      final h = int.parse(time24.split(':')[0]);
      final period = h < 12 ? 'AM' : 'PM';
      final display = h == 0 ? 12 : h <= 12 ? h : h - 12;
      return '$display:00 $period';
    } catch (_) {
      return time24;
    }
  }

  /// Formats a time range e.g. '9:00 AM – 11:00 AM'.
  static String formatTimeRange(String start, String end) {
    return '${formatHour(start)} – ${formatHour(end)}';
  }

  /// Returns the emoji for a sport name.
  static String sportEmoji(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
        return '⚽';
      case 'cricket':
        return '🏏';
      case 'badminton':
        return '🏸';
      case 'tennis':
        return '🎾';
      default:
        return '🏟️';
    }
  }
}
