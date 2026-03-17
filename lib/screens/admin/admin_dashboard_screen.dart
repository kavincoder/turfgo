import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(allBookingsStreamProvider);
    final turfsAsync = ref.watch(allTurfsStreamProvider);
    final usersAsync = ref.watch(allUsersStreamProvider);
    final today = _todayStr();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: bookingsAsync.when(
          loading: () => const _ShimmerDashboard(),
          error: (_, __) =>
              const Center(child: Text('Something went wrong')),
          data: (allBookings) {
            final turfs = turfsAsync.valueOrNull ?? [];
            final users = usersAsync.valueOrNull ?? [];

            final confirmedBookings = allBookings
                .where((b) => b.status == BookingStatus.confirmed)
                .toList();

            final todayBookings = confirmedBookings
                .where((b) => b.slotDate == today)
                .toList();

            final totalRevenue = confirmedBookings.fold<double>(
                0, (sum, b) => sum + b.totalAmount);

            final todayRevenue = todayBookings.fold<double>(
                0, (sum, b) => sum + b.totalAmount);

            final activeTurfs =
                turfs.where((t) => t.isActive).length;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(24.r),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTextStyles.bodyFont,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          DateFormat('EEEE, MMM d yyyy')
                              .format(DateTime.now()),
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontFamily: AppTextStyles.bodyFont,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // ── Today's stats ───────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTextStyles.bodyFont,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.calendar_today_rounded,
                            label: 'Bookings',
                            value: '${todayBookings.length}',
                            iconColor: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.currency_rupee_rounded,
                            label: 'Revenue',
                            value: '₹${todayRevenue.toInt()}',
                            iconColor: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // ── Overall stats ──────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(
                      'Overall',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTextStyles.bodyFont,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Total Revenue',
                            value: '₹${totalRevenue.toInt()}',
                            iconColor: const Color(0xFF7C3AED),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.receipt_long_rounded,
                            label: 'Total Bookings',
                            value: '${confirmedBookings.length}',
                            iconColor: const Color(0xFF2563EB),
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
                            icon: Icons.stadium_rounded,
                            label: 'Active Turfs',
                            value: '$activeTurfs / ${turfs.length}',
                            iconColor: const Color(0xFFD97706),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.people_rounded,
                            label: 'Total Users',
                            value: '${users.length}',
                            iconColor: const Color(0xFFDB2777),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 28.h),

                  // ── Recent bookings ─────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(
                      'Recent Bookings',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTextStyles.bodyFont,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),

                  if (allBookings.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 20.w, vertical: 40.h),
                      child: Center(
                        child: Text(
                          'No bookings yet',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                            fontFamily: AppTextStyles.bodyFont,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      itemCount: allBookings.length > 10
                          ? 10
                          : allBookings.length,
                      itemBuilder: (_, i) {
                        final b = allBookings[i];
                        return Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.turfName.isNotEmpty
                                          ? b.turfName
                                          : 'Booking',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        fontFamily:
                                            AppTextStyles.bodyFont,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      '${b.sport} · ${b.slotDate}',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color:
                                            AppColors.textSecondary,
                                        fontFamily:
                                            AppTextStyles.bodyFont,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${b.totalAmount.toInt()}',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w700,
                                      fontFamily:
                                          AppTextStyles.bodyFont,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6.w,
                                        vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: (b.status ==
                                                  BookingStatus
                                                      .confirmed
                                              ? AppColors.primary
                                              : AppColors.grey)
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(6.r),
                                    ),
                                    child: Text(
                                      b.status,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                        fontFamily:
                                            AppTextStyles.bodyFont,
                                        color: b.status ==
                                                BookingStatus
                                                    .confirmed
                                            ? AppColors.primary
                                            : AppColors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  SizedBox(height: 24.h),
                ],
              ),
            );
          },
        ),
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
                children: List.generate(
                  2,
                  (_) => Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: 12.w),
                      height: 110.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
