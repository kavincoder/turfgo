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
  });

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  bool get isAvailable => !isBooked && !isLocked;

  factory Slot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Slot(
      id: doc.id,
      date: data['date'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      isBooked: data['isBooked'] ?? false,
      bookingId: data['bookingId'],
      sport: data['sport'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      lockedUntil: (data['lockedUntil'] as Timestamp?)?.toDate(),
      lockedBy: data['lockedBy'],
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'isBooked': isBooked,
        'bookingId': bookingId,
        'sport': sport,
        'price': price,
        'lockedUntil':
            lockedUntil != null ? Timestamp.fromDate(lockedUntil!) : null,
        'lockedBy': lockedBy,
      };
}
