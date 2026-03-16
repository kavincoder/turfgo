import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (prev, next) {
      // Ensure the Firestore user document exists whenever a user session is
      // restored (e.g. app relaunch with persisted auth) — not just on fresh
      // sign-in. This prevents update() failures on non-existent documents.
      final user = next.valueOrNull;
      if (user != null) {
        _ref.read(authRepositoryProvider).ensureUserDoc(user);
      }
      notifyListeners();
    });
  }

  String? redirect(context, state) {
    final authState = _ref.read(authStateProvider);

    // While auth state is loading, stay on splash
    if (authState.isLoading) return null;

    final isLoggedIn = authState.valueOrNull != null;
    final loc = state.matchedLocation;
    final isAuthRoute =
        loc == '/' || loc == '/login' || loc == '/otp';

    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && isAuthRoute) return '/home';
    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>(
  (ref) => RouterNotifier(ref),
);
