import 'package:cloud_firestore/cloud_firestore.dart';

class Slot {
  final String id;
  final String date; // e.g. '2026-03-16'
  final String startTime; // e.g. '18:00'
  final String endTime; // e.g. '19:00'
  final bool isBooked;
  final String? bookingId;
  final String sport;
  final double price;
  final DateTime? lockedUntil;
  final String? lockedBy;

  // ── Multi-court fields ──────────────────────────────────────────────────────
  /// Total physical courts at this turf for this sport.
  final int courtCount;

  /// Courts held for coaching during this hour (set at seed time, never changes).
  final int coachingReserved;

  /// Player bookings so far (increments with each booking).
  final int bookedCount;

  /// All booking IDs for this slot (replaces single bookingId).
  final List<String> bookingIds;

  const Slot({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.isBooked,
    this.bookingId,
    required this.sport,
    required this.price,
    this.lockedUntil,
    this.lockedBy,
    this.courtCount = 1,
    this.coachingReserved = 0,
    this.bookedCount = 0,
    this.bookingIds = const [],
  });

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  /// Courts still bookable by players right now.
  int get availableCount =>
      (courtCount - coachingReserved - bookedCount).clamp(0, courtCount);

  /// True when at least one court is free and no owner lock is active.
  bool get isAvailable => availableCount > 0 && !isLocked;

  factory Slot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final bool isBooked = data['isBooked'] ?? false;

    // Backward compat: derive bookedCount from isBooked if field is absent.
    final rawBookedCount = data['bookedCount'];
    final int bookedCount = rawBookedCount != null
        ? (rawBookedCount as num).toInt()
        : (isBooked ? 1 : 0);

    // Backward compat: derive bookingIds from single bookingId if absent.
    final rawBookingIds = data['bookingIds'];
    final List<String> bookingIds;
    if (rawBookingIds is List) {
      bookingIds = List<String>.from(rawBookingIds);
    } else {
      final single = data['bookingId'] as String?;
      bookingIds = single != null ? [single] : [];
    }

    return Slot(
      id: doc.id,
      date: data['date'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      isBooked: isBooked,
      bookingId: data['bookingId'],
      sport: data['sport'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      lockedUntil: (data['lockedUntil'] as Timestamp?)?.toDate(),
      lockedBy: data['lockedBy'],
      courtCount: (data['courtCount'] as num?)?.toInt() ?? 1,
      coachingReserved: (data['coachingReserved'] as num?)?.toInt() ?? 0,
      bookedCount: bookedCount,
      bookingIds: bookingIds,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'isBooked': isBooked,
        'bookingId': bookingId,
        'bookingIds': bookingIds,
        'sport': sport,
        'price': price,
        'lockedUntil':
            lockedUntil != null ? Timestamp.fromDate(lockedUntil!) : null,
        'lockedBy': lockedBy,
        'courtCount': courtCount,
        'coachingReserved': coachingReserved,
        'bookedCount': bookedCount,
      };
}
