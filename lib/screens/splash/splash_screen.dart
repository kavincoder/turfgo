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
    // Quick brand flash, then straight to login
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        context.go(user != null ? '/home' : '/login');
      }
    });
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
