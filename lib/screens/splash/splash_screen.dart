import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../providers/user_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Minimum splash duration for branding
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    await _route();
  }

  Future<void> _route() async {
    if (!mounted) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      context.go('/home');
      return;
    }

    // Fresh Firestore read — never uses a stale Riverpod stream.
    // Retries up to 3 times with a short back-off so a slow network
    // doesn't accidentally drop the admin to the player home.
    String role = UserRole.player;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        role = await ref.read(userRepositoryProvider).fetchRole(firebaseUser.uid) ??
            UserRole.player;
        break; // success — stop retrying
      } catch (e, st) {
        debugPrint('Splash role fetch attempt ${attempt + 1} failed: $e\n$st');
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 1));
        }
        // On final failure keep default 'player' role
      }
    }

    if (!mounted) return;
    switch (role) {
      case UserRole.admin:
        context.go('/admin');
      case UserRole.owner:
        context.go('/owner');
      default:
        context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Text(
          'TurfGo',
          style: TextStyle(
            fontFamily: AppTextStyles.displayFont,
            fontSize: 48.sp,
            color: AppColors.primary,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
