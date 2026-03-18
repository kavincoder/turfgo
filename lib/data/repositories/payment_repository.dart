import 'package:cloud_functions/cloud_functions.dart';

/// Handles all Razorpay payment operations via Firebase Cloud Functions.
/// No Razorpay secrets ever touch the client — all sensitive operations
/// (order creation, signature verification, booking confirmation) happen server-side.
class PaymentRepository {
  final _functions = FirebaseFunctions.instance;

  /// Locks one or more slots for 5 minutes for this user.
  /// For multi-hour bookings, pass all slot IDs in the selected range.
  /// Returns the lock expiry timestamp in milliseconds.
  Future<int> lockSlots({
    required String turfId,
    required List<String> slotIds,
  }) async {
    final callable = _functions.httpsCallable('lockSlot');
    final result = await callable.call({
      'turfId': turfId,
      'slotIds': slotIds,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['lockedUntilMs'] as num).toInt();
  }

  /// Creates a Razorpay order server-side and returns the orderId.
  /// Amount must be in paise (₹100 = 10000 paise).
  /// turfId is stored server-side so createBooking can verify the payment
  /// was for the correct turf, preventing cross-turf payment reuse.
  Future<Map<String, dynamic>> createRazorpayOrder({
    required int amountInPaise,
    required String receipt,
    required String turfId,
  }) async {
    final callable = _functions.httpsCallable('createRazorpayOrder');
    final result = await callable.call({
      'amountInPaise': amountInPaise,
      'receipt': receipt,
      'turfId': turfId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Verifies Razorpay signature server-side and creates the booking atomically.
  /// Only call this after receiving EVENT_PAYMENT_SUCCESS from Razorpay.
  /// advancePaid is derived server-side from the stored order — not passed by client.
  /// Returns the newly created bookingId.
  Future<String> createBooking({
    required String turfId,
    required String turfName,
    required String cityId,
    required List<String> slotIds,
    required String slotDate,
    required String slotStartTime,
    required String slotEndTime,
    required String sport,
    required int totalAmount,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    final callable = _functions.httpsCallable('createBooking');
    final result = await callable.call({
      'turfId': turfId,
      'turfName': turfName,
      'cityId': cityId,
      'slotIds': slotIds,
      'slotDate': slotDate,
      'slotStartTime': slotStartTime,
      'slotEndTime': slotEndTime,
      'sport': sport,
      'totalAmount': totalAmount,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpayOrderId': razorpayOrderId,
      'razorpaySignature': razorpaySignature,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['bookingId'] as String;
  }
}
