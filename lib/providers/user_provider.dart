import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/user_repository.dart';
import '../models/app_user.dart';
import 'auth_provider.dart';

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  // Watch authStateProvider so this provider automatically rebuilds
  // whenever the signed-in user changes (sign out, sign in, switch accounts).
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final uid = authUser?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(userRepositoryProvider).userStream(uid);
});
