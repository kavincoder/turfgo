import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/review_repository.dart';
import '../models/review.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(),
);

/// Streams all verified reviews for a given turf, ordered by newest first.
final turfReviewsProvider =
    StreamProvider.family<List<Review>, String>((ref, turfId) {
  return ref.watch(reviewRepositoryProvider).getTurfReviewsStream(turfId);
});
