import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../models/slot.dart';
import '../../models/turf.dart';
import '../../providers/turf_provider.dart';
import '../booking_confirmation/booking_confirmation_screen.dart';

class SlotSelectionScreen extends ConsumerStatefulWidget {
  final Turf turf;

  const SlotSelectionScreen({super.key, required this.turf});

  @override
  ConsumerState<SlotSelectionScreen> createState() =>
      _SlotSelectionScreenState();
}

class _SlotSelectionScreenState
    extends ConsumerState<SlotSelectionScreen> {
  late DateTime _selectedDate;
  late String _selectedSport;
  int? _selectedSlotIndex;
  int _duration = 1;

  final _dates = List.generate(7, (i) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + i);
  });

  @override
  void initState() {
    super.initState();
    _selectedDate = _dates[0];
    _selectedSport = widget.turf.sports.first;
  }

  // Hours available for this turf based on its open/close time
  List<int> get _slotHours {
    final open = _parseHour(widget.turf.openTime);
    final close = _parseHour(widget.turf.closeTime);
    return List.generate(close - open, (i) => open + i);
  }

  int _parseHour(String time) => int.parse(time.split(':')[0]);

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isPastSlot(int hour) {
    if (!_isToday(_selectedDate)) return false;
    return hour <= DateTime.now().hour;
  }

  bool _isOutOfBounds(int index) =>
      index + _duration > _slotHours.length;

  bool _isInSelection(int index) {
    if (_selectedSlotIndex == null) return false;
    return index >= _selectedSlotIndex! &&
        index < _selectedSlotIndex! + _duration;
  }

  bool _isSelectionStart(int index) => index == _selectedSlotIndex;

  bool _isSelectionEnd(int index) =>
      _selectedSlotIndex != null &&
      index == _selectedSlotIndex! + _duration - 1;

  String _formatHour(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final display =
        hour == 0 ? 12 : hour <= 12 ? hour : hour - 12;
    return '$display:00 $period';
  }

  String _toStartTimeStr(int hour) =>
      '${hour.toString().padLeft(2, '0')}:00';

  double get _totalPrice => widget.turf.pricePerHour * _duration;

  String get _slotLabel {
    if (_selectedSlotIndex == null) return '';
    final startHour = _slotHours[_selectedSlotIndex!];
    final endHour = startHour + _duration;
    return '${_formatHour(startHour)} – ${_formatHour(endHour)}';
  }

  void _onDurationChanged(double val) {
    final newDuration = val.toInt();
    setState(() {
      _duration = newDuration;
      if (_selectedSlotIndex != null &&
          _selectedSlotIndex! + newDuration > _slotHours.length) {
        _selectedSlotIndex = null;
      }
    });
  }

  void _proceed() {
    if (_selectedSlotIndex == null) return;

    // Collect the actual Slot objects for the selected time range
    final slotsData = ref
            .read(slotsProvider(
                (turfId: widget.turf.id, date: TurfDateUtils.toDateString(_selectedDate))))
            .valueOrNull ??
        [];

    final selectedSlots = <Slot>[];
    for (int i = 0; i < _duration; i++) {
      final hour = _slotHours[_selectedSlotIndex! + i];
      final startTime = _toStartTimeStr(hour);

      Slot? match;
      for (final s in slotsData) {
        if (s.startTime == startTime && s.sport == _selectedSport) {
          match = s;
          break;
        }
      }

      if (match == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Slot data unavailable. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      selectedSlots.add(match);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(
          turf: widget.turf,
          selectedSlots: selectedSlots,
          selectedDate: _selectedDate,
          slotLabel: _slotLabel,
          duration: _duration,
          sport: _selectedSport,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final dateStr = TurfDateUtils.toDateString(_selectedDate);
    final slotsAsync = ref.watch(
      slotsProvider((turfId: widget.turf.id, date: dateStr)),
    );

    // Build set of unavailable startTimes for the selected sport
    final unavailableStartTimes = slotsAsync.whenOrNull(
          data: (slots) => slots
              .where((s) =>
                  s.sport == _selectedSport && !s.isAvailable)
              .map((s) => s.startTime)
              .toSet(),
        ) ??
        {};

    // Map startTime → Slot for court-count badge lookup
    final slotByStartTime = slotsAsync.whenOrNull(
          data: (slots) => Map.fromEntries(
            slots
                .where((s) => s.sport == _selectedSport)
                .map((s) => MapEntry(s.startTime, s)),
          ),
        ) ??
        {};

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.turf.name,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              widget.turf.area,
              style: TextStyle(
                fontSize: 12.sp,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: 90.h + bottomPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sport selector (only shown for multi-sport turfs)
                if (widget.turf.sports.length > 1) ...[
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.w, vertical: 14.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Sport',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTextStyles.bodyFont,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: widget.turf.sports.map((sport) {
                            final isSelected =
                                sport == _selectedSport;
                            return Padding(
                              padding: EdgeInsets.only(right: 10.w),
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _selectedSport = sport;
                                  _selectedSlotIndex = null;
                                }),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: Text(
                                    sport,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: AppTextStyles.bodyFont,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],

                // Date picker
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Text(
                          'Select Date',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTextStyles.bodyFont,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20.w),
                        child: Row(
                          children: _dates.map((date) {
                            final isSelected =
                                date.day == _selectedDate.day &&
                                    date.month == _selectedDate.month;
                            final isToday = _isToday(date);
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedDate = date;
                                _selectedSlotIndex = null;
                              }),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                margin: EdgeInsets.only(right: 10.w),
                                width: 58.w,
                                padding:
                                    EdgeInsets.symmetric(vertical: 12.h),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      isToday
                                          ? 'Today'
                                          : DateFormat('EEE').format(date),
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontFamily: AppTextStyles.bodyFont,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                                .withValues(alpha: 0.85)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      date.day.toString(),
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: AppTextStyles.bodyFont,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      DateFormat('MMM').format(date),
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontFamily: AppTextStyles.bodyFont,
                                        color: isSelected
                                            ? Colors.white
                                                .withValues(alpha: 0.85)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12.h),

                // Duration slider
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(
                      horizontal: 20.w, vertical: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Duration',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTextStyles.bodyFont,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 14.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              '$_duration ${_duration == 1 ? 'hour' : 'hours'}  ·  ${AppFormat.price(widget.turf.pricePerHour * _duration)}',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                fontFamily: AppTextStyles.bodyFont,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: AppColors.greyLight,
                          thumbColor: AppColors.primary,
                          overlayColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          trackHeight: 4,
                          thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius: 10.r),
                        ),
                        child: Slider(
                          value: _duration.toDouble(),
                          min: 1,
                          max: 4,
                          divisions: 3,
                          onChanged: _onDurationChanged,
                        ),
                      ),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: List.generate(4, (i) {
                          final val = i + 1;
                          return Text(
                            '${val}h',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontFamily: AppTextStyles.bodyFont,
                              color: _duration == val
                                  ? AppColors.primary
                                  : AppColors.grey,
                              fontWeight: _duration == val
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12.h),

                // Legend
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(
                      horizontal: 20.w, vertical: 14.h),
                  child: Row(
                    children: [
                      _LegendDot(
                          color: AppColors.primary,
                          label: 'Available'),
                      SizedBox(width: 20.w),
                      _LegendDot(
                          color: AppColors.greyLight,
                          label: 'Unavailable'),
                      SizedBox(width: 20.w),
                      _LegendDot(
                          color: AppColors.primary,
                          label: 'Selected',
                          filled: true),
                    ],
                  ),
                ),

                SizedBox(height: 12.h),

                // Slot grid
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Start Time',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTextStyles.bodyFont,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Booking will cover $_duration consecutive ${_duration == 1 ? 'hour' : 'hours'}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontFamily: AppTextStyles.bodyFont,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Skeleton while slots are loading
                      if (slotsAsync.isLoading)
                        Shimmer.fromColors(
                          baseColor: Colors.grey[200]!,
                          highlightColor: Colors.grey[100]!,
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10.w,
                              mainAxisSpacing: 10.h,
                              childAspectRatio: 2.4,
                            ),
                            itemCount: _slotHours.length,
                            itemBuilder: (_, __) => Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius:
                                    BorderRadius.circular(10.r),
                              ),
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10.w,
                            mainAxisSpacing: 10.h,
                            childAspectRatio: 2.0,
                          ),
                          itemCount: _slotHours.length,
                          itemBuilder: (context, index) {
                            final hour = _slotHours[index];
                            final startTime = _toStartTimeStr(hour);
                            final isPast = _isPastSlot(hour);
                            final isOob = _isOutOfBounds(index);
                            final isBooked = unavailableStartTimes
                                .contains(startTime);
                            final disabled =
                                isPast || isOob || isBooked;
                            final inSelection = _isInSelection(index);
                            final isStart = _isSelectionStart(index);
                            final isEnd = _isSelectionEnd(index);

                            // Multi-court badge
                            final slotForBadge = slotByStartTime[startTime];
                            final showCourtBadge = !disabled &&
                                slotForBadge != null &&
                                slotForBadge.courtCount > 1;
                            final availableCount =
                                slotForBadge?.availableCount ?? 1;

                            BorderRadius radius;
                            if (_duration == 1 || (isStart && isEnd)) {
                              radius = BorderRadius.circular(10.r);
                            } else if (isStart) {
                              radius = BorderRadius.horizontal(
                                left: Radius.circular(10.r),
                                right: Radius.circular(3.r),
                              );
                            } else if (isEnd) {
                              radius = BorderRadius.horizontal(
                                left: Radius.circular(3.r),
                                right: Radius.circular(10.r),
                              );
                            } else if (inSelection) {
                              radius = BorderRadius.circular(3.r);
                            } else {
                              radius = BorderRadius.circular(10.r);
                            }

                            return GestureDetector(
                              onTap: disabled
                                  ? null
                                  : () => setState(
                                      () => _selectedSlotIndex = index),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: disabled
                                      ? AppColors.greyLight
                                      : inSelection
                                          ? AppColors.primary
                                          : AppColors.primaryLight,
                                  borderRadius: radius,
                                  border: Border.all(
                                    color: disabled
                                        ? AppColors.greyLight
                                        : inSelection
                                            ? AppColors.primary
                                            : AppColors.primary
                                                .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _formatHour(hour),
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: AppTextStyles.bodyFont,
                                        color: disabled
                                            ? AppColors.grey
                                            : inSelection
                                                ? Colors.white
                                                : AppColors.primary,
                                      ),
                                    ),
                                    if (showCourtBadge) ...[
                                      SizedBox(height: 2.h),
                                      Text(
                                        '$availableCount left',
                                        style: TextStyle(
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: AppTextStyles.bodyFont,
                                          color: inSelection
                                              ? Colors.white
                                                  .withValues(alpha: 0.85)
                                              : AppColors.primary
                                                  .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom proceed button
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
              child: ElevatedButton(
                onPressed: _selectedSlotIndex != null ? _proceed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.greyLight,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: AppColors.grey,
                  minimumSize: Size(double.infinity, 54.h),
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
                child: Text(
                  _selectedSlotIndex != null
                      ? 'Proceed  ·  $_slotLabel  ·  ${AppFormat.price(_totalPrice)}'
                      : 'Select a Start Time',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool filled;

  const _LegendDot({
    required this.color,
    required this.label,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14.w,
          height: 14.w,
          decoration: BoxDecoration(
            color: filled ? color : AppColors.primaryLight,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        SizedBox(width: 6.w),
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
