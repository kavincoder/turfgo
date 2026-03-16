import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final String turfName;
  final String area;
  final String imageUrl;
  final DateTime selectedDate;
  final String slotLabel;
  final int duration;
  final double pricePerHour;

  const BookingConfirmationScreen({
    super.key,
    required this.turfName,
    required this.area,
    required this.imageUrl,
    required this.selectedDate,
    required this.slotLabel,
    required this.duration,
    required this.pricePerHour,
  });

  double get _basePrice => pricePerHour * duration;
  double get _totalPrice => _basePrice;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back,
                size: 20.sp, color: AppColors.textPrimary),
          ),
        ),
        title: Text(
          'Confirm Booking',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: 100.h + bottomPad),
            child: Column(
              children: [
                SizedBox(height: 16.h),

                // ── Turf card ─────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(16.r)),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 100.w,
                            height: 90.h,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 100.w,
                              height: 90.h,
                              color: const Color(0xFF1B4332),
                              child: Icon(Icons.sports_soccer,
                                  size: 28.sp,
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 100.w,
                              height: 90.h,
                              color: const Color(0xFF1B4332),
                              child: Icon(Icons.sports,
                                  size: 28.sp,
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(14.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  turfName,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: AppTextStyles.bodyFont,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined,
                                        size: 13.sp,
                                        color: AppColors.textSecondary),
                                    SizedBox(width: 3.w),
                                    Text(
                                      area,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: AppColors.textSecondary,
                                        fontFamily: AppTextStyles.bodyFont,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Booking details ───────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking Details',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTextStyles.bodyFont,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        _DetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date',
                          value: DateFormat('EEEE, MMM d yyyy')
                              .format(selectedDate),
                        ),
                        _DetailRow(
                          icon: Icons.access_time_rounded,
                          label: 'Time',
                          value: slotLabel,
                        ),
                        _DetailRow(
                          icon: Icons.hourglass_bottom_rounded,
                          label: 'Duration',
                          value:
                              '$duration ${duration == 1 ? 'hour' : 'hours'}',
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Price breakdown ───────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price Breakdown',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTextStyles.bodyFont,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        _PriceRow(
                          label:
                              '₹${pricePerHour.toInt()} × $duration ${duration == 1 ? 'hr' : 'hrs'}',
                          value: '₹${_basePrice.toInt()}',
                        ),
                        SizedBox(height: 14.h),
                        Container(
                          height: 1,
                          color: AppColors.border,
                        ),
                        SizedBox(height: 14.h),
                        _PriceRow(
                          label: 'Total',
                          value: '₹${_totalPrice.toInt()}',
                          isBold: true,
                          valueColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Policy note ───────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16.sp, color: AppColors.primary),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Cancellations made 24 hours before the slot are eligible for a full refund.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.primary,
                              fontFamily: AppTextStyles.bodyFont,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Pay Now button ─────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20.w, 12.h, 20.w, bottomPad + 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Payable',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                          fontFamily: AppTextStyles.bodyFont,
                        ),
                      ),
                      Text(
                        '₹${_totalPrice.toInt()}',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontFamily: AppTextStyles.bodyFont,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Wire Razorpay in Phase 4
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Payment coming soon!'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 54.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: 0,
                      textStyle: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                    child: const Text('Pay Now'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 18.sp, color: AppColors.primary),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  fontFamily: AppTextStyles.bodyFont,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTextStyles.bodyFont,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 15.sp : 14.sp,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
            fontFamily: AppTextStyles.bodyFont,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16.sp : 14.sp,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            fontFamily: AppTextStyles.bodyFont,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
