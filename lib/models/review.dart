import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String userId;
  final String turfId;
  final String bookingId;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final bool isVerified;

  const Review({
    required this.id,
    required this.userId,
    required this.turfId,
    required this.bookingId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.isVerified,
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      userId: data['userId'] ?? '',
      turfId: data['turfId'] ?? '',
      bookingId: data['bookingId'] ?? '',
      rating: data['rating'] ?? 0,
      comment: data['comment'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVerified: data['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'turfId': turfId,
        'bookingId': bookingId,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': isVerified,
      };
}
