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
            itemBuilder: (_, i) =>
                _BookingCard(booking: upcoming[i], today: today),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final String today;

  const _BookingCard({required this.booking, required this.today});

  Color get _statusColor => BookingStatus.color(booking.status);
  String get _statusLabel => BookingStatus.label(booking.status);
  String get _formattedDate => TurfDateUtils.formatDate(booking.slotDate);
  String get _sportEmoji => TurfDateUtils.sportEmoji(booking.sport);
  bool get _isFuture => booking.slotDate.compareTo(today) > 0;

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 40.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Text(_sportEmoji, style: TextStyle(fontSize: 28.sp)),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    booking.turfName.isNotEmpty
                        ? booking.turfName
                        : 'TurfGo Booking',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTextStyles.bodyFont,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
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
            SizedBox(height: 20.h),
            _DetailRow(label: 'Sport', value: booking.sport),
            _DetailRow(label: 'Date', value: _formattedDate),
            _DetailRow(
              label: 'Time',
              value: TurfDateUtils.formatTimeRange(
                  booking.slotStartTime, booking.slotEndTime),
            ),
            _DetailRow(
                label: 'Amount Paid',
                value: AppFormat.price(booking.advancePaid)),
            _DetailRow(
                label: 'Total',
                value: AppFormat.price(booking.totalAmount)),
            _DetailRow(
              label: 'Booking ID',
              value: booking.id.isNotEmpty
                  ? booking.id.substring(0, 8).toUpperCase()
                  : '—',
            ),
            if (_isFuture &&
                booking.status == BookingStatus.confirmed) ...[
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCancelInfo(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: Size(double.infinity, 48.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Cancel Booking',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTextStyles.bodyFont,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCancelInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'Cancel Booking',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Self-serve cancellation is coming soon.\n\nTo cancel now, WhatsApp us at +91 98765 43210 with your Booking ID: ${booking.id.isNotEmpty ? booking.id.substring(0, 8).toUpperCase() : booking.id}',
          style: TextStyle(
            fontSize: 14.sp,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontFamily: AppTextStyles.bodyFont,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
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
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
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
                                color: _statusColor.withValues(alpha: 0.12),
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
                              label: TurfDateUtils.formatTimeRange(
                                  booking.slotStartTime,
                                  booking.slotEndTime),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppFormat.price(booking.totalAmount),
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                fontFamily: AppTextStyles.bodyFont,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Tap for details',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontFamily: AppTextStyles.bodyFont,
                                    color: AppColors.grey,
                                  ),
                                ),
                                SizedBox(width: 2.w),
                                Icon(Icons.chevron_right_rounded,
                                    size: 14.sp, color: AppColors.grey),
                              ],
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
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
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
