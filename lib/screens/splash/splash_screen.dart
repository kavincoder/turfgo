import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 800), _routeByRole);
  }

  Future<void> _routeByRole() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    // Fetch role from Firestore to decide where to land
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final role = doc.data()?['role'] ?? 'player';
      switch (role) {
        case UserRole.owner:
          context.go('/owner');
        case UserRole.admin:
          context.go('/admin');
        default:
          context.go('/home');
      }
    } catch (_) {
      // Fallback to player home if Firestore read fails
      if (mounted) context.go('/home');
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
