import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/review.dart';

class ReviewRepository {
  final _db = FirebaseFirestore.instance;

  Stream<List<Review>> getTurfReviewsStream(String turfId) {
    return _db
        .collection('reviews')
        .where('turfId', isEqualTo: turfId)
        .where('isVerified', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Review.fromFirestore).toList());
  }
}
