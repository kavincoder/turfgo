import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

class Booking {
  final String id;
  final String userId;
  final String turfId;
  final String turfName; // denormalized at booking creation by Cloud Function
  final String cityId;
  final String sport;
  final String slotDate; // 'YYYY-MM-DD'
  final String slotStartTime;
  final String slotEndTime;
  final double totalAmount;
  final double advancePaid;
  final String? paymentId;
  final String? razorpayOrderId;
  final String status; // pending, confirmed, completed, cancelled, no_show
  final DateTime? refundWindowExpiry;
  final String payoutStatus; // pending, processed, failed
  final DateTime? cancelledAt;
  final double? refundAmount;
  final DateTime createdAt;

  const Booking({
    required this.id,
    required this.userId,
    required this.turfId,
    this.turfName = '',
    required this.cityId,
    required this.sport,
    required this.slotDate,
    required this.slotStartTime,
    required this.slotEndTime,
    required this.totalAmount,
    required this.advancePaid,
    this.paymentId,
    this.razorpayOrderId,
    required this.status,
    this.refundWindowExpiry,
    this.payoutStatus = 'pending',
    this.cancelledAt,
    this.refundAmount,
    required this.createdAt,
  });

  bool get isUpcoming {
    if (status != BookingStatus.confirmed) return false;
    try {
      return DateTime.parse('$slotDate $slotStartTime').isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      userId: data['userId'] ?? '',
      turfId: data['turfId'] ?? '',
      turfName: data['turfName'] ?? '',
      cityId: data['cityId'] ?? '',
      sport: data['sport'] ?? '',
      slotDate: data['slotDate'] ?? '',
      slotStartTime: data['slotStartTime'] ?? '',
      slotEndTime: data['slotEndTime'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      advancePaid: (data['advancePaid'] ?? 0).toDouble(),
      paymentId: data['paymentId'],
      razorpayOrderId: data['razorpayOrderId'],
      status: data['status'] ?? 'pending',
      refundWindowExpiry:
          (data['refundWindowExpiry'] as Timestamp?)?.toDate(),
      payoutStatus: data['payoutStatus'] ?? 'pending',
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      refundAmount: (data['refundAmount'] as num?)?.toDouble(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'turfId': turfId,
        'turfName': turfName,
        'cityId': cityId,
        'sport': sport,
        'slotDate': slotDate,
        'slotStartTime': slotStartTime,
        'slotEndTime': slotEndTime,
        'totalAmount': totalAmount,
        'advancePaid': advancePaid,
        'paymentId': paymentId,
        'razorpayOrderId': razorpayOrderId,
        'status': status,
        'refundWindowExpiry': refundWindowExpiry != null
            ? Timestamp.fromDate(refundWindowExpiry!)
            : null,
        'payoutStatus': payoutStatus,
        'cancelledAt':
            cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
        'refundAmount': refundAmount,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
