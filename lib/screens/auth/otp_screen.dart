import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String verificationId;
  final String phone;
  final int? resendToken;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phone,
    this.resendToken,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _error;
  late String _verificationId;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otp,
      );
      await ref.read(authRepositoryProvider).signInWithCredential(credential);
      if (!mounted) return;
      final router = GoRouter.of(context);
      // Pop both OTP and login in one synchronous sequence so neither
      // screen is ever painted — user goes directly to the calling screen.
      if (router.canPop()) router.pop(); // pop OTP → login
      if (router.canPop()) router.pop(); // pop login → slot selection / booking
      // If nothing was poppable (login was root), the router redirect
      // (isLoggedIn && isAuthRoute → '/') handles navigation automatically.
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.code == 'invalid-verification-code'
              ? 'Wrong OTP. Please try again.'
              : (e.message ?? 'Verification failed.');
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _error = null);

    final repo = ref.read(authRepositoryProvider);

    try {
      await repo.verifyPhoneNumber(
        phoneNumber: '+91${widget.phone}',
        timeout: const Duration(seconds: 60),
        forceResendingToken: widget.resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification disabled — users must always enter OTP manually.
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _error = e.message ?? 'Failed to resend OTP.');
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() => _verificationId = verificationId);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OTP resent')),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.code == 'resource-exhausted'
              ? 'Too many OTP requests. Please try again tomorrow.'
              : 'Something went wrong. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 24.h),
              Text(
                'Verify OTP',
                style: TextStyle(
                  fontFamily: AppTextStyles.bodyFont,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Enter the 6-digit code sent to +91 ${widget.phone}',
                style: TextStyle(
                  fontFamily: AppTextStyles.bodyFont,
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 32.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 48.w,
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        fontFamily: AppTextStyles.bodyFont,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      onChanged: (value) {
                        if (_error != null) setState(() => _error = null);
                        if (value.isNotEmpty && i < 5) {
                          _focusNodes[i + 1].requestFocus();
                        }
                        if (value.isEmpty && i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                        if (_otp.length == 6) _verifyOtp();
                      },
                    ),
                  );
                }),
              ),
              if (_error != null) ...[
                SizedBox(height: 16.h),
                Text(
                  _error!,
                  style: TextStyle(
                    fontFamily: AppTextStyles.bodyFont,
                    fontSize: 13.sp,
                    color: AppColors.error,
                  ),
                ),
              ],
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? SizedBox(
                        height: 20.h,
                        width: 20.h,
                        child: const CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Verify'),
              ),
              SizedBox(height: 16.h),
              Center(
                child: TextButton(
                  onPressed: _resendOtp,
                  child: Text(
                    "Didn't receive code? Resend",
                    style: TextStyle(
                      fontFamily: AppTextStyles.bodyFont,
                      fontSize: 14.sp,
                      color: AppColors.primary,
                    ),
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
