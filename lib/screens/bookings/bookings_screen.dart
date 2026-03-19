import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../models/booking.dart';
import '../../providers/booking_provider.dart';

class BookingsScreen extends ConsumerWidget {
  final VoidCallback onExploreTurfs;

  const BookingsScreen({super.key, required this.onExploreTurfs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(bookingsStreamProvider);
    final today = TurfDateUtils.todayString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Bookings',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: bookingsAsync.when(
        loading: () => const _ShimmerList(),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded,
                    size: 48.sp, color: AppColors.grey),
                SizedBox(height: 16.h),
                Text(
                  'Could not load your bookings',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTextStyles.bodyFont,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  'Check your internet connection and try again.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textSecondary,
                    fontFamily: AppTextStyles.bodyFont,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (bookings) {
          final upcoming = bookings
              .where((b) =>
                  b.status == BookingStatus.confirmed &&
                  b.slotDate.compareTo(today) >= 0)
              .toList();

          if (upcoming.isEmpty) {
            return _EmptyState(onExploreTurfs: onExploreTurfs);
          }

          return ListView.builder(
            padding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            itemCount: upcoming.length,
            itemBuilder: (_, i) => _BookingCard(booking: upcoming[i]),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;

  const _BookingCard({required this.booking});

  Color get _statusColor => BookingStatus.color(booking.status);
  String get _statusLabel => BookingStatus.label(booking.status);

  String get _formattedDate => TurfDateUtils.formatDate(booking.slotDate);

  String get _sportEmoji => TurfDateUtils.sportEmoji(booking.sport);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4.w, color: _statusColor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_sportEmoji,
                              style: TextStyle(fontSize: 22.sp)),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.turfName.isNotEmpty
                                      ? booking.turfName
                                      : 'TurfGo Booking',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: AppTextStyles.bodyFont,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  booking.sport,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontFamily: AppTextStyles.bodyFont,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color:
                                  _statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              _statusLabel,
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppTextStyles.bodyFont,
                                color: _statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Divider(color: AppColors.border, height: 1),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.calendar_today_rounded,
                            label: _formattedDate,
                          ),
                          SizedBox(width: 12.w),
                          _InfoChip(
                            icon: Icons.access_time_rounded,
                            label:
                                TurfDateUtils.formatTimeRange(booking.slotStartTime, booking.slotEndTime),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${booking.totalAmount.toInt()}',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTextStyles.bodyFont,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Advance: ₹${booking.advancePaid.toInt()}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontFamily: AppTextStyles.bodyFont,
                              color: AppColors.textSecondary,
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
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.sp, color: AppColors.textSecondary),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onExploreTurfs;

  const _EmptyState({required this.onExploreTurfs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90.w,
              height: 90.w,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 44.sp,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Upcoming Bookings',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "You haven't booked any turfs yet.\nFind one near you and get playing!",
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                fontFamily: AppTextStyles.bodyFont,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: onExploreTurfs,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 52.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                elevation: 0,
                textStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTextStyles.bodyFont,
                ),
              ),
              child: const Text('Explore Turfs'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          margin: EdgeInsets.only(bottom: 12.h),
          height: 130.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
      ),
    );
  }
}
