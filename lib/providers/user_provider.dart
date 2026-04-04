import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/user_repository.dart';
import '../models/app_user.dart';
import 'auth_provider.dart';

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(userRepositoryProvider).userStream(uid);
});
