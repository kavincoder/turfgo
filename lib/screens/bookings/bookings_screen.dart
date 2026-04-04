import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../data/repositories/payment_repository.dart';
import '../../models/booking.dart';
import '../../providers/booking_provider.dart';

class BookingsScreen extends ConsumerWidget {
  final VoidCallback onExploreTurfs;

  const BookingsScreen({super.key, required this.onExploreTurfs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(bookingsStreamProvider);
    final today = TurfDateUtils.todayString();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              fontFamily: AppTextStyles.bodyFont,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 14.sp,
              fontFamily: AppTextStyles.bodyFont,
            ),
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: bookingsAsync.when(
          loading: () => const _ShimmerList(),
          error: (e, _) => _ErrorState(),
          data: (bookings) {
            final upcoming = bookings
                .where((b) =>
                    b.status == BookingStatus.confirmed &&
                    b.slotDate.compareTo(today) >= 0)
                .toList()
              ..sort((a, b) => a.slotDate.compareTo(b.slotDate));

            final past = bookings
                .where((b) =>
                    b.status != BookingStatus.confirmed ||
                    b.slotDate.compareTo(today) < 0)
                .toList()
              ..sort((a, b) => b.slotDate.compareTo(a.slotDate));

            return TabBarView(
              children: [
                upcoming.isEmpty
                    ? _EmptyState(onExploreTurfs: onExploreTurfs)
                    : _BookingList(bookings: upcoming, today: today),
                past.isEmpty
                    ? _EmptyPast()
                    : _BookingList(
                        bookings: past, today: today, showCancel: false),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Booking list ──────────────────────────────────────────────────────────────

class _BookingList extends StatelessWidget {
  final List<Booking> bookings;
  final String today;
  final bool showCancel;

  const _BookingList({
    required this.bookings,
    required this.today,
    this.showCancel = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      itemCount: bookings.length,
      itemBuilder: (_, i) => _BookingCard(
        booking: bookings[i],
        today: today,
        showCancel: showCancel,
      ),
    );
  }
}

// ── Booking card ──────────────────────────────────────────────────────────────

class _BookingCard extends ConsumerStatefulWidget {
  final Booking booking;
  final String today;
  final bool showCancel;

  const _BookingCard({
    required this.booking,
    required this.today,
    this.showCancel = true,
  });

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  bool _cancelling = false;
  final _paymentRepo = PaymentRepository();

  Color get _statusColor => BookingStatus.color(widget.booking.status);
  String get _statusLabel => BookingStatus.label(widget.booking.status);
  String get _formattedDate =>
      TurfDateUtils.formatDate(widget.booking.slotDate);
  String get _sportEmoji => TurfDateUtils.sportEmoji(widget.booking.sport);

  // Refund eligibility — server is authoritative; this is just for display
  bool get _isRefundEligible {
    try {
      final slotDt = DateTime.parse(
          '${widget.booking.slotDate} ${widget.booking.slotStartTime}');
      final hoursLeft = slotDt.difference(DateTime.now()).inHours;
      return hoursLeft > 24;
    } catch (_) {
      return false;
    }
  }

  bool get _isFutureSlot {
    try {
      final slotDt = DateTime.parse(
          '${widget.booking.slotDate} ${widget.booking.slotStartTime}');
      return slotDt.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  void _showDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => _DetailsSheet(
        booking: widget.booking,
        isFutureSlot: _isFutureSlot,
        isRefundEligible: _isRefundEligible,
        showCancel: widget.showCancel,
        cancelling: _cancelling,
        onCancel: () {
          Navigator.pop(context);
          _confirmCancel();
        },
      ),
    );
  }

  void _confirmCancel() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'Cancel Booking?',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isRefundEligible
                  ? 'You\'re cancelling more than 24 hours before the slot.'
                  : 'You\'re cancelling within 24 hours of the slot.',
              style: TextStyle(
                fontSize: 14.sp,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: _isRefundEligible
                    ? AppColors.primaryLight
                    : AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Icon(
                    _isRefundEligible
                        ? Icons.check_circle_rounded
                        : Icons.info_rounded,
                    size: 18.sp,
                    color: _isRefundEligible
                        ? AppColors.primary
                        : AppColors.error,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _isRefundEligible
                          ? '₹${widget.booking.advancePaid.toInt()} will be refunded in 5–7 business days.'
                          : 'The advance of ₹${widget.booking.advancePaid.toInt()} is non-refundable.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTextStyles.bodyFont,
                        color: _isRefundEligible
                            ? AppColors.primary
                            : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed:
                _cancelling ? null : () => Navigator.pop(context),
            child: Text(
              'Keep Booking',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontFamily: AppTextStyles.bodyFont,
              ),
            ),
          ),
          TextButton(
            onPressed: _cancelling
                ? null
                : () {
                    Navigator.pop(context);
                    _doCancel();
                  },
            child: Text(
              'Yes, Cancel',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                fontFamily: AppTextStyles.bodyFont,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doCancel() async {
    setState(() => _cancelling = true);
    try {
      final result = await _paymentRepo.cancelBooking(
        bookingId: widget.booking.id,
      );
      if (!mounted) return;
      final message = result['message'] as String? ?? 'Booking cancelled.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              fontFamily: AppTextStyles.bodyFont,
              fontSize: 13.sp,
            ),
          ),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r)),
          margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('already')
          ? 'This booking has already been cancelled.'
          : e.toString().contains('started')
              ? 'Cannot cancel a booking that has already started.'
              : 'Could not cancel booking. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: TextStyle(
              fontFamily: AppTextStyles.bodyFont,
              fontSize: 13.sp,
            ),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r)),
          margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showDetails,
      child: Opacity(
        opacity: _cancelling ? 0.5 : 1.0,
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
                                      widget.booking.turfName.isNotEmpty
                                          ? widget.booking.turfName
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
                                      widget.booking.sport,
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
                                  _cancelling ? 'Cancelling…' : _statusLabel,
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
                                    widget.booking.slotStartTime,
                                    widget.booking.slotEndTime),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppFormat.price(widget.booking.totalAmount),
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
      ),
    );
  }
}

// ── Details bottom sheet ──────────────────────────────────────────────────────

class _DetailsSheet extends StatelessWidget {
  final Booking booking;
  final bool isFutureSlot;
  final bool isRefundEligible;
  final bool showCancel;
  final bool cancelling;
  final VoidCallback onCancel;

  const _DetailsSheet({
    required this.booking,
    required this.isFutureSlot,
    required this.isRefundEligible,
    required this.showCancel,
    required this.cancelling,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = BookingStatus.color(booking.status);
    final statusLabel = BookingStatus.label(booking.status);

    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 40.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
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
          // Header
          Row(
            children: [
              Text(
                TurfDateUtils.sportEmoji(booking.sport),
                style: TextStyle(fontSize: 28.sp),
              ),
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
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTextStyles.bodyFont,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _DetailRow(label: 'Sport', value: booking.sport),
          _DetailRow(
              label: 'Date',
              value: TurfDateUtils.formatDate(booking.slotDate)),
          _DetailRow(
            label: 'Time',
            value: TurfDateUtils.formatTimeRange(
                booking.slotStartTime, booking.slotEndTime),
          ),
          _DetailRow(
            label: 'Slot total',
            value: AppFormat.price(booking.totalSlotPrice),
          ),
          _DetailRow(
            label: 'Paid online',
            value: AppFormat.price(booking.advancePaid),
          ),
          _DetailRow(
            label: 'Due at venue',
            value: AppFormat.price(booking.balanceDueAtVenue),
          ),
          _DetailRow(
            label: 'Booking ID',
            value: booking.id.isNotEmpty
                ? booking.id.substring(0, 8).toUpperCase()
                : '—',
          ),
          // Cancel button — only for future confirmed bookings
          if (showCancel &&
              isFutureSlot &&
              booking.status == BookingStatus.confirmed) ...[
            SizedBox(height: 8.h),
            // Refund policy hint
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: isRefundEligible
                    ? AppColors.primaryLight
                    : AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Icon(
                    isRefundEligible
                        ? Icons.check_circle_outline_rounded
                        : Icons.warning_amber_rounded,
                    size: 16.sp,
                    color: isRefundEligible
                        ? AppColors.primary
                        : AppColors.warning,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      isRefundEligible
                          ? 'Cancelling now gives a full advance refund.'
                          : 'Cancelling now forfeits your advance (< 24 h to slot).',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontFamily: AppTextStyles.bodyFont,
                        color: isRefundEligible
                            ? AppColors.primary
                            : AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: cancelling ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                      color: cancelling
                          ? AppColors.greyLight
                          : AppColors.error),
                  minimumSize: Size(double.infinity, 48.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  cancelling ? 'Cancelling…' : 'Cancel Booking',
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
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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

// ── Empty states ──────────────────────────────────────────────────────────────

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

class _EmptyPast extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 48.sp, color: AppColors.greyLight),
          SizedBox(height: 16.h),
          Text(
            'No past bookings yet',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              fontFamily: AppTextStyles.bodyFont,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48.sp, color: AppColors.grey),
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
