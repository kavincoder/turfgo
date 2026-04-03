import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../data/repositories/auth_repository.dart';
import '../providers/user_provider.dart';

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

    // Splash handles its own role-based routing — don't interfere
    if (loc == '/') return null;

    // /owner-login is accessible to anyone — logged in or not.
    // A logged-in player can use it to switch to their owner account.
    if (loc == '/owner-login') return null;

    final isAuthRoute = loc == '/login' || loc == '/otp';

    if (!isLoggedIn && !isAuthRoute) return '/login';
    // Logged-in user on login/otp → send to splash for role routing
    if (isLoggedIn && isAuthRoute) return '/';

    // ── Role-based route guards ───────────────────────────────────────────────
    // Prevent cross-role navigation (e.g. player calling context.go('/admin')).
    // If the role hasn't loaded yet, hold on splash — splash will re-route once
    // the Firestore read completes. This is safe: the route is never rendered.
    if (isLoggedIn && (loc == '/admin' || loc == '/owner')) {
      final userAsync = _ref.read(currentUserProvider);
      if (userAsync.isLoading) return null; // splash already verified role — allow through
      final role = userAsync.valueOrNull?.role;
      if (loc == '/admin' && role != UserRole.admin) return '/';
      if (loc == '/owner' && role != UserRole.owner) return '/';
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>(
  (ref) => RouterNotifier(ref),
);
