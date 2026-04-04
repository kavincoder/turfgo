import 'package:cloud_firestore/cloud_firestore.dart';

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
  final double totalSlotPrice;    // full slot price (server-computed)
  final double advancePaid;       // 20% paid online
  final double commission;        // TurfGo's cut
  final double commissionRate;    // e.g. 0.13
  final double ownerPayout;       // advance minus commission
  final double balanceDueAtVenue; // 80% paid at venue
  final List<String> slotIds;     // slot doc IDs covered by this booking
  // kept for backward-compat with existing code that reads totalAmount
  double get totalAmount => totalSlotPrice;
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
    required this.totalSlotPrice,
    required this.advancePaid,
    this.commission = 0,
    this.commissionRate = 0.13,
    this.ownerPayout = 0,
    this.balanceDueAtVenue = 0,
    this.slotIds = const [],
    this.paymentId,
    this.razorpayOrderId,
    required this.status,
    this.refundWindowExpiry,
    this.payoutStatus = 'pending',
    this.cancelledAt,
    this.refundAmount,
    required this.createdAt,
  });

  bool get isUpcoming =>
      status == 'confirmed' &&
      DateTime.parse('$slotDate $slotStartTime').isAfter(DateTime.now());

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
      totalSlotPrice: (data['totalSlotPrice'] ?? data['totalAmount'] ?? 0).toDouble(),
      advancePaid: (data['advancePaid'] ?? 0).toDouble(),
      commission: (data['commission'] ?? 0).toDouble(),
      commissionRate: (data['commissionRate'] ?? 0.13).toDouble(),
      ownerPayout: (data['ownerPayout'] ?? 0).toDouble(),
      balanceDueAtVenue: (data['balanceDueAtVenue'] ?? 0).toDouble(),
      slotIds: List<String>.from(data['slotIds'] ?? []),
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
        'totalSlotPrice': totalSlotPrice,
        'advancePaid': advancePaid,
        'commission': commission,
        'commissionRate': commissionRate,
        'ownerPayout': ownerPayout,
        'balanceDueAtVenue': balanceDueAtVenue,
        'slotIds': slotIds,
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
