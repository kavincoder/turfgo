import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../providers/owner_provider.dart';

class OwnerBookingsScreen extends ConsumerStatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  ConsumerState<OwnerBookingsScreen> createState() =>
      _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends ConsumerState<OwnerBookingsScreen> {
  late DateTime _selectedDate;

  final _dates = List.generate(7, (i) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + i);
  });

  @override
  void initState() {
    super.initState();
    _selectedDate = _dates[0];
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _fmt(String time24) {
    try {
      final h = int.parse(time24.split(':')[0]);
      final period = h < 12 ? 'AM' : 'PM';
      final display = h == 0 ? 12 : h <= 12 ? h : h - 12;
      return '$display:00 $period';
    } catch (_) {
      return time24;
    }
  }

  String _sportEmoji(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
        return '⚽';
      case 'cricket':
        return '🏏';
      case 'badminton':
        return '🏸';
      default:
        return '🏟️';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case BookingStatus.confirmed:
        return AppColors.primary;
      case BookingStatus.pending:
        return AppColors.warning;
      case BookingStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.completed:
        return 'Completed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(ownerBookingsProvider);
    final selectedDateStr = _dateKey(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Bookings',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Date picker ────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(bottom: 12.h),
            child: SizedBox(
              height: 72.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: _dates.length,
                itemBuilder: (_, i) {
                  final date = _dates[i];
                  final isSelected = _dateKey(date) == selectedDateStr;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = date),
                    child: Container(
                      width: 56.w,
                      margin: EdgeInsets.only(right: 8.w),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppColors.primary : AppColors.background,
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('EEE').format(date).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              fontFamily: AppTextStyles.bodyFont,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTextStyles.bodyFont,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (_isToday(date))
                            Container(
                              margin: EdgeInsets.only(top: 2.h),
                              width: 5.w,
                              height: 5.w,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Bookings list ──────────────────────────────────
          Expanded(
            child: bookingsAsync.when(
              loading: () => const _ShimmerList(),
              error: (_, __) =>
                  const Center(child: Text('Something went wrong')),
              data: (allBookings) {
                final dayBookings = allBookings
                    .where((b) => b.slotDate == selectedDateStr)
                    .toList();

                if (dayBookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded,
                            size: 48.sp, color: AppColors.grey),
                        SizedBox(height: 12.h),
                        Text(
                          _isToday(_selectedDate)
                              ? 'No bookings today'
                              : 'No bookings on this day',
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: AppColors.textSecondary,
                            fontFamily: AppTextStyles.bodyFont,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final dayEarnings = dayBookings
                    .where((b) => b.status == BookingStatus.confirmed)
                    .fold<double>(0, (sum, b) => sum + b.totalAmount);

                return Column(
                  children: [
                    // ── Day summary ───────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${dayBookings.length} ${dayBookings.length == 1 ? 'booking' : 'bookings'}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              fontFamily: AppTextStyles.bodyFont,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '₹${dayEarnings.toInt()}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTextStyles.bodyFont,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 8.h),
                        itemCount: dayBookings.length,
                        itemBuilder: (_, i) {
                          final b = dayBookings[i];
                          return Container(
                            margin: EdgeInsets.only(bottom: 10.h),
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14.r),
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
                                Text(_sportEmoji(b.sport),
                                    style: TextStyle(fontSize: 28.sp)),
                                SizedBox(width: 14.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            b.sport,
                                            style: TextStyle(
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.w700,
                                              fontFamily:
                                                  AppTextStyles.bodyFont,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8.w,
                                                vertical: 2.h),
                                            decoration: BoxDecoration(
                                              color: _statusColor(b.status)
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(8.r),
                                            ),
                                            child: Text(
                                              _statusLabel(b.status),
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w600,
                                                fontFamily:
                                                    AppTextStyles.bodyFont,
                                                color:
                                                    _statusColor(b.status),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4.h),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded,
                                              size: 12.sp,
                                              color:
                                                  AppColors.textSecondary),
                                          SizedBox(width: 4.w),
                                          Text(
                                            '${_fmt(b.slotStartTime)} – ${_fmt(b.slotEndTime)}',
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
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${b.totalAmount.toInt()}',
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
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          margin: EdgeInsets.only(bottom: 10.h),
          height: 80.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      ),
    );
  }
}
