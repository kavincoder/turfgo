import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/review.dart';

class ReviewRepository {
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;

  /// Submit a review via Cloud Function.
  /// Enforces: 1 review per user per day, 1 review per user per turf (ever),
  /// and requires a confirmed booking for the turf.
  Future<String> submitReview({
    required String turfId,
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    final result = await _functions.httpsCallable('submitReview').call({
      'turfId': turfId,
      'bookingId': bookingId,
      'rating': rating,
      'comment': comment,
    });
    return result.data['reviewId'] as String;
  }

  /// Stream all verified reviews for a turf, newest first.
  Stream<List<Review>> getTurfReviewsStream(String turfId) {
    return _db
        .collection('reviews')
        .where('turfId', isEqualTo: turfId)
        .where('isVerified', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Review.fromFirestore).toList());
  }

  /// Check if the current user has already reviewed a specific turf.
  Future<bool> hasReviewed({
    required String userId,
    required String turfId,
  }) async {
    final snap = await _db
        .collection('reviews')
        .where('userId', isEqualTo: userId)
        .where('turfId', isEqualTo: turfId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
