import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/constants.dart';
import '../../data/repositories/payment_repository.dart';
import '../../models/slot.dart';
import '../../models/turf.dart';
import '../../providers/user_provider.dart';
import '../booking_success/booking_success_screen.dart';

// RAZORPAY_KEY_ID is a public key — safe to ship in the client.
// Pass it at build time: flutter run --dart-define=RAZORPAY_KEY_ID=rzp_test_xxx
const _kRazorpayKeyId = String.fromEnvironment(
  'RAZORPAY_KEY_ID',
  defaultValue: 'rzp_test_placeholder',
);

enum _PaymentState { idle, loading, failed }

class BookingConfirmationScreen extends ConsumerStatefulWidget {
  final Turf turf;
  final List<Slot> selectedSlots;
  final DateTime selectedDate;
  final String slotLabel;
  final int duration;
  final String sport;

  const BookingConfirmationScreen({
    super.key,
    required this.turf,
    required this.selectedSlots,
    required this.selectedDate,
    required this.slotLabel,
    required this.duration,
    required this.sport,
  });

  @override
  ConsumerState<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends ConsumerState<BookingConfirmationScreen> {
  late final Razorpay _razorpay;
  _PaymentState _paymentState = _PaymentState.idle;
  String? _errorMessage;
  String? _pendingOrderId;

  final _paymentRepo = PaymentRepository();

  // Computed helpers
  String get _slotDate {
    final d = widget.selectedDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String get _slotStartTime => widget.selectedSlots.first.startTime;
  String get _slotEndTime => widget.selectedSlots.last.endTime;
  int get _totalAmount => (widget.turf.pricePerHour * widget.duration).toInt();
  int get _totalInPaise => _totalAmount * 100;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _startPayment() async {
    setState(() {
      _paymentState = _PaymentState.loading;
      _errorMessage = null;
    });

    try {
      final slotIds = widget.selectedSlots.map((s) => s.id).toList();

      // Step 1: Lock all selected slots for 5 minutes
      await _paymentRepo.lockSlots(
        turfId: widget.turf.id,
        slotIds: slotIds,
      );

      // Step 2: Create Razorpay order server-side
      final receipt =
          'tgo_${DateTime.now().millisecondsSinceEpoch}'.substring(0, 40);
      final orderData = await _paymentRepo.createRazorpayOrder(
        amountInPaise: _totalInPaise,
        receipt: receipt,
      );
      _pendingOrderId = orderData['orderId'] as String;

      // Step 3: Prefill user details
      final user = ref.read(currentUserProvider).valueOrNull;

      // Step 4: Open Razorpay payment sheet
      _razorpay.open({
        'key': _kRazorpayKeyId,
        'amount': _totalInPaise,
        'order_id': _pendingOrderId,
        'name': 'TurfGo',
        'description': '${widget.turf.name} · ${widget.slotLabel}',
        'prefill': {
          'contact': user?.phone ?? '',
          'name': user?.name ?? '',
        },
        'theme': {'color': '#00C96A'},
        'modal': {'backdropclose': false},
      });
      // State stays loading until a Razorpay callback fires
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _paymentState = _PaymentState.failed;
        _errorMessage = _friendlyFunctionsError(e);
      });
    } catch (e) {
      setState(() {
        _paymentState = _PaymentState.failed;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final slotIds = widget.selectedSlots.map((s) => s.id).toList();

      final bookingId = await _paymentRepo.createBooking(
        turfId: widget.turf.id,
        turfName: widget.turf.name,
        cityId: widget.turf.cityId,
        slotIds: slotIds,
        slotDate: _slotDate,
        slotStartTime: _slotStartTime,
        slotEndTime: _slotEndTime,
        sport: widget.sport,
        totalAmount: _totalAmount,
        advancePaid: _totalAmount,
        razorpayPaymentId: response.paymentId ?? '',
        razorpayOrderId: response.orderId ?? _pendingOrderId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      if (!mounted) return;

      // Pop back to home and push success screen on top
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            turfName: widget.turf.name,
            slotLabel: widget.slotLabel,
            selectedDate: widget.selectedDate,
            totalPaid: _totalAmount,
            bookingId: bookingId,
          ),
        ),
        (route) => route.isFirst,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _paymentState = _PaymentState.failed;
        _errorMessage =
            'Payment received but booking failed. Contact support with payment ID: ${response.paymentId}. Error: ${e.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paymentState = _PaymentState.failed;
        _errorMessage =
            'Payment received but booking failed. Contact support with payment ID: ${response.paymentId}';
      });
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    final userCancelled = response.code == Razorpay.PAYMENT_CANCELLED;
    setState(() {
      _paymentState = _PaymentState.failed;
      _errorMessage = userCancelled
          ? 'Payment cancelled. Your slot is held for a few minutes — try again.'
          : (response.message ?? 'Payment failed. Please try again.');
    });
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    // External wallet (PhonePe, Paytm, etc.) — Razorpay handles completion
    // via success/error callbacks after the wallet flow finishes
  }

  String _friendlyFunctionsError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'already-exists':
        return 'This slot was just taken by someone else. Please go back and choose a different slot.';
      case 'failed-precondition':
        return 'Your slot hold expired. Please go back and select the slot again.';
      case 'unauthenticated':
        return 'Session expired. Please log in again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isLoading = _paymentState == _PaymentState.loading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: isLoading ? null : () => Navigator.pop(context),
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
            padding: EdgeInsets.only(bottom: 120.h + bottomPad),
            child: Column(
              children: [
                SizedBox(height: 16.h),

                // ── Turf card ────────────────────────────────────
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
                            imageUrl: widget.turf.photos.isNotEmpty
                                ? widget.turf.photos[0]
                                : '',
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
                                  widget.turf.name,
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
                                      widget.turf.area,
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

                // ── Booking details ──────────────────────────────
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
                          icon: Icons.sports_outlined,
                          label: 'Sport',
                          value: widget.sport,
                        ),
                        _DetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date',
                          value: DateFormat('EEEE, MMM d yyyy')
                              .format(widget.selectedDate),
                        ),
                        _DetailRow(
                          icon: Icons.access_time_rounded,
                          label: 'Time',
                          value: widget.slotLabel,
                        ),
                        _DetailRow(
                          icon: Icons.hourglass_bottom_rounded,
                          label: 'Duration',
                          value:
                              '${widget.duration} ${widget.duration == 1 ? 'hour' : 'hours'}',
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Price breakdown ──────────────────────────────
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
                              '₹${widget.turf.pricePerHour.toInt()} × ${widget.duration} ${widget.duration == 1 ? 'hr' : 'hrs'}',
                          value: '₹$_totalAmount',
                        ),
                        SizedBox(height: 14.h),
                        Container(height: 1, color: AppColors.border),
                        SizedBox(height: 14.h),
                        _PriceRow(
                          label: 'Total',
                          value: '₹$_totalAmount',
                          isBold: true,
                          valueColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Error message ────────────────────────────────
                if (_paymentState == _PaymentState.failed &&
                    _errorMessage != null)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 16.sp, color: AppColors.error),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.error,
                                fontFamily: AppTextStyles.bodyFont,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                SizedBox(height: 16.h),

                // ── Policy note ──────────────────────────────────
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

          // ── Bottom Pay Now button ────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, bottomPad + 12.h),
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
                        '₹$_totalAmount',
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
                    onPressed: isLoading ? null : _startPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 54.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18.w,
                                height: 18.w,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Text(
                                'Securing your slot…',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: AppTextStyles.bodyFont,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _paymentState == _PaymentState.failed
                                ? 'Try Again'
                                : 'Pay ₹$_totalAmount',
                            style: TextStyle(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTextStyles.bodyFont,
                            ),
                          ),
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
