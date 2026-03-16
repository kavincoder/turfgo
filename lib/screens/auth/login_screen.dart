import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final repo = ref.read(authRepositoryProvider);

    await repo.verifyPhoneNumber(
      phoneNumber: '+91$phone',
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification (Android only)
        await repo.signInWithCredential(credential);
        if (mounted) context.go('/home');
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = e.message ?? 'Verification failed. Try again.';
          });
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() => _isLoading = false);
          context.push('/otp', extra: {
            'verificationId': verificationId,
            'phone': phone,
            'resendToken': resendToken,
          });
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 60.h),
              Text(
                'TurfGo',
                style: TextStyle(
                  fontFamily: AppTextStyles.displayFont,
                  fontSize: 40.sp,
                  color: AppColors.primary,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Book your turf in seconds',
                style: TextStyle(
                  fontFamily: AppTextStyles.bodyFont,
                  fontSize: 16.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 48.h),
              Text(
                'Phone number',
                style: TextStyle(
                  fontFamily: AppTextStyles.bodyFont,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: TextStyle(
                  fontFamily: AppTextStyles.bodyFont,
                  fontSize: 16.sp,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your mobile number',
                  counterText: '',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(left: 16.w, right: 8.w),
                    child: Text(
                      '+91',
                      style: TextStyle(
                        fontFamily: AppTextStyles.bodyFont,
                        fontSize: 16.sp,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                child: _isLoading
                    ? SizedBox(
                        height: 20.h,
                        width: 20.h,
                        child: const CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Get OTP'),
              ),
              const Spacer(),
              Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 24.h),
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    style: TextStyle(
                      fontFamily: AppTextStyles.bodyFont,
                      fontSize: 12.sp,
                      color: AppColors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
