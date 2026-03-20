import 'dart:async';

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
  Timer? _timeout;
  bool _routed = false;

  @override
  void initState() {
    super.initState();

    // Minimum splash display time
    Future.delayed(const Duration(milliseconds: 800), _tryRoute);

    // Hard timeout — if Firestore never responds, fall back after 6 seconds
    _timeout = Timer(const Duration(seconds: 6), () {
      _routeTo(FirebaseAuth.instance.currentUser != null ? '/home' : '/login');
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _tryRoute() {
    if (!mounted || _routed) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _routeTo('/login');
      return;
    }

    // Check if currentUserProvider already has data loaded
    final userAsync = ref.read(currentUserProvider);
    userAsync.whenData((appUser) {
      if (appUser != null) {
        _routeByRole(appUser.role);
      }
      // If null doc, wait for listener below
    });

    // Listen for the first data emission from Firestore
    ref.listenManual(currentUserProvider, (prev, next) {
      if (_routed || !mounted) return;
      next.whenData((appUser) {
        _routeByRole(appUser?.role ?? UserRole.player);
      });
    });
  }

  void _routeByRole(String role) {
    switch (role) {
      case UserRole.admin:
        _routeTo('/admin');
      case UserRole.owner:
        _routeTo('/owner');
      default:
        _routeTo('/home');
    }
  }

  void _routeTo(String path) {
    if (_routed || !mounted) return;
    _routed = true;
    _timeout?.cancel();
    context.go(path);
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
