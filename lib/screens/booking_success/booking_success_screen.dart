import 'package:confetti/confetti.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';

class BookingSuccessScreen extends StatefulWidget {
  final String turfName;
  final String slotLabel;
  final DateTime selectedDate;
  final int totalPaid;
  final String bookingId;

  const BookingSuccessScreen({
    super.key,
    required this.turfName,
    required this.slotLabel,
    required this.selectedDate,
    required this.totalPaid,
    required this.bookingId,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Confetti
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 40,
            colors: const [
              AppColors.primary,
              Color(0xFF34D399),
              Color(0xFFFBBF24),
              Color(0xFF60A5FA),
              Color(0xFFF472B6),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  SizedBox(height: 60.h),

                  // ── Success icon ─────────────────────────────
                  Container(
                    width: 100.w,
                    height: 100.w,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 52.sp,
                      color: AppColors.primary,
                    ),
                  ),

                  SizedBox(height: 28.h),

                  Text(
                    'Booking Confirmed!',
                    style: TextStyle(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w800,
                      fontFamily: AppTextStyles.bodyFont,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  Text(
                    'Your slot is locked in. See you on the turf!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                      fontFamily: AppTextStyles.bodyFont,
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: 36.h),

                  // ── Booking summary card ─────────────────────
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: 'Turf',
                          value: widget.turfName,
                        ),
                        _Divider(),
                        _SummaryRow(
                          label: 'Date',
                          value: DateFormat('EEE, MMM d yyyy')
                              .format(widget.selectedDate),
                        ),
                        _Divider(),
                        _SummaryRow(
                          label: 'Time',
                          value: widget.slotLabel,
                        ),
                        _Divider(),
                        _SummaryRow(
                          label: 'Paid',
                          value: '₹${widget.totalPaid}',
                          valueColor: AppColors.primary,
                          valueBold: true,
                        ),
                        _Divider(),
                        _SummaryRow(
                          label: 'Booking ID',
                          value: widget.bookingId.substring(0, 8).toUpperCase(),
                          valueColor: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ── Buttons ──────────────────────────────────
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 54.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'View My Bookings',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                  ),

                  SizedBox(height: 12.h),

                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text(
                      'Back to Home',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                  ),

                  SizedBox(height: bottomPad + 12.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: valueBold ? FontWeight.w700 : FontWeight.w600,
                fontFamily: AppTextStyles.bodyFont,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.border);
  }
}
