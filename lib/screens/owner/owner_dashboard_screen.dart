import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../models/booking.dart';
import '../../providers/owner_provider.dart';
import '../../providers/user_provider.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final bookingsAsync = ref.watch(ownerBookingsProvider);
    final today = TurfDateUtils.todayString();

    final userName = userAsync.valueOrNull?.name.trim() ?? '';
    final greeting = userName.isNotEmpty ? 'Hello, $userName!' : 'Hello!';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bookingsAsync.when(
        loading: () => const _ShimmerDashboard(),
        error: (_, __) =>
            const Center(child: Text('Something went wrong')),
        data: (allBookings) {
          // Today's confirmed bookings
          final todayBookings = allBookings
              .where((b) =>
                  b.slotDate == today &&
                  b.status == BookingStatus.confirmed)
              .toList();

          // Today's earnings
          final todayEarnings = todayBookings.fold<double>(
              0, (sum, b) => sum + b.totalAmount);

          // Upcoming bookings (today + future, confirmed)
          final upcoming = allBookings
              .where((b) =>
                  b.status == BookingStatus.confirmed &&
                  b.slotDate.compareTo(today) >= 0)
              .toList();

          // Total all-time earnings
          final totalEarnings = allBookings
              .where((b) => b.status == BookingStatus.confirmed)
              .fold<double>(0, (sum, b) => sum + b.totalAmount);

          // All-time cancelled bookings count
          final cancelledCount = allBookings
              .where((b) => b.status == BookingStatus.cancelled)
              .length;

          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(24.r),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTextStyles.bodyFont,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          TurfDateUtils.formatDateLong(TurfDateUtils.todayString()),
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontFamily: AppTextStyles.bodyFont,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // ── Stat cards ──────────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.calendar_today_rounded,
                            label: "Today's Bookings",
                            value: '${todayBookings.length}',
                            iconColor: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.currency_rupee_rounded,
                            label: "Today's Earnings",
                            value: AppFormat.price(todayEarnings),
                            iconColor: AppColors.emerald,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 12.h),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.upcoming_rounded,
                            label: 'Upcoming',
                            value: '${upcoming.length}',
                            iconColor: AppColors.blue,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Total Earned',
                            value: AppFormat.price(totalEarnings),
                            iconColor: AppColors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 12.h),

                  // ── Cancelled stat ──────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.cancel_rounded,
                            label: 'Cancelled',
                            value: '$cancelledCount',
                            iconColor: AppColors.error,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),

                  SizedBox(height: 28.h),

                  // ── Upcoming bookings list ──────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(
                      'Upcoming Bookings',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTextStyles.bodyFont,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  SizedBox(height: 14.h),

                  if (upcoming.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 20.w, vertical: 32.h),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 72.w,
                              height: 72.w,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.calendar_month_rounded,
                                size: 36.sp,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'No upcoming bookings',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontFamily: AppTextStyles.bodyFont,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'Share your turf to start getting bookings.',
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
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      itemCount: upcoming.length > 10 ? 10 : upcoming.length,
                      itemBuilder: (_, i) {
                        final b = upcoming[i];
                        final isToday = b.slotDate == today;
                        return _UpcomingCard(
                          booking: b,
                          isToday: isToday,
                          sportEmoji: TurfDateUtils.sportEmoji(b.sport),
                          timeLabel: TurfDateUtils.formatTimeRange(
                              b.slotStartTime, b.slotEndTime),
                        );
                      },
                    ),

                  SizedBox(height: 24.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 18.sp, color: iconColor),
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              fontFamily: AppTextStyles.bodyFont,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.textSecondary,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final Booking booking;
  final bool isToday;
  final String sportEmoji;
  final String timeLabel;

  const _UpcomingCard({
    required this.booking,
    required this.isToday,
    required this.sportEmoji,
    required this.timeLabel,
  });

  String get _dateLabel {
    if (isToday) return 'Today';
    return TurfDateUtils.formatDate(booking.slotDate);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: isToday
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(sportEmoji, style: TextStyle(fontSize: 28.sp)),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.sport,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTextStyles.bodyFont,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 12.sp, color: AppColors.textSecondary),
                    SizedBox(width: 4.w),
                    Text(
                      '$_dateLabel · $timeLabel',
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
          Text(
            AppFormat.price(booking.totalAmount),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              fontFamily: AppTextStyles.bodyFont,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerDashboard extends StatelessWidget {
  const _ShimmerDashboard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 100.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24.r)),
              ),
            ),
            SizedBox(height: 20.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 110.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Container(
                      height: 110.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            ...List.generate(
              3,
              (_) => Container(
                margin: EdgeInsets.symmetric(
                    horizontal: 20.w, vertical: 6.h),
                height: 80.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
