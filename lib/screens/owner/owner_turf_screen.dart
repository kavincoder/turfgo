import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../models/slot.dart';
import '../../models/turf.dart';
import '../../providers/owner_provider.dart';
import '../../providers/turf_provider.dart';

class OwnerTurfScreen extends ConsumerWidget {
  const OwnerTurfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turfsAsync = ref.watch(ownerTurfsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Turf',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (turfsAsync.valueOrNull?.isNotEmpty == true)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              tooltip: 'Edit turf',
              onPressed: () {
                final turf = turfsAsync.valueOrNull!.first;
                context
                    .push('/owner/turf-edit', extra: turf)
                    .then((_) => ref.invalidate(ownerTurfsProvider));
              },
            ),
        ],
      ),
      body: turfsAsync.when(
        loading: () => const _ShimmerTurf(),
        error: (_, __) =>
            const Center(child: Text('Could not load turf details')),
        data: (turfs) {
          if (turfs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stadium_outlined,
                      size: 56.sp, color: AppColors.grey),
                  SizedBox(height: 16.h),
                  Text(
                    'No turf registered',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.textSecondary,
                      fontFamily: AppTextStyles.bodyFont,
                    ),
                  ),
                ],
              ),
            );
          }

          final turf = turfs.first;
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 2.5,
                    labelStyle: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTextStyles.bodyFont,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 14.sp,
                      fontFamily: AppTextStyles.bodyFont,
                    ),
                    tabs: const [
                      Tab(text: 'Details'),
                      Tab(text: 'Slot Manager'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _TurfDetails(
                          turf: turf, amenityIcon: AmenityUtils.icon),
                      _SlotManager(turf: turf),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Slot Manager ──────────────────────────────────────────────────────────────

class _SlotManager extends ConsumerStatefulWidget {
  final Turf turf;
  const _SlotManager({required this.turf});

  @override
  ConsumerState<_SlotManager> createState() => _SlotManagerState();
}

class _SlotManagerState extends ConsumerState<_SlotManager> {
  late DateTime _selectedDate;
  late String _selectedSport;

  final _dates = List.generate(14, (i) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + i);
  });

  @override
  void initState() {
    super.initState();
    _selectedDate = _dates[0];
    _selectedSport = widget.turf.sports.first;
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isPast(String startTime) {
    if (!_isToday(_selectedDate)) return false;
    final hour = int.tryParse(startTime.split(':')[0]) ?? 0;
    return hour <= DateTime.now().hour;
  }

  Future<void> _confirmLock(Slot slot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Block Slot'),
        content: Text(
          'Block ${TurfDateUtils.formatHour(slot.startTime)} on '
          '${DateFormat('d MMM').format(_selectedDate)} for $_selectedSport?\n\n'
          'Players won\'t be able to book this slot.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block',
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref
          .read(slotRepositoryProvider)
          .ownerLockSlot(widget.turf.id, slot.id);
    } catch (e, st) {
      debugPrint('Owner block slot failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to block slot')),
        );
      }
    }
  }

  Future<void> _confirmUnlock(Slot slot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unblock Slot'),
        content: Text(
          'Unblock ${TurfDateUtils.formatHour(slot.startTime)} on '
          '${DateFormat('d MMM').format(_selectedDate)} for $_selectedSport?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unblock',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref
          .read(slotRepositoryProvider)
          .ownerUnlockSlot(widget.turf.id, slot.id);
    } catch (e, st) {
      debugPrint('Owner unblock slot failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unblock slot')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = TurfDateUtils.toDateString(_selectedDate);
    final slotsAsync = ref.watch(
      slotsProvider((turfId: widget.turf.id, date: dateStr)),
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date picker ────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: _dates.map((date) {
                  final isSelected = date.day == _selectedDate.day &&
                      date.month == _selectedDate.month;
                  final isToday = _isToday(date);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = date),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(right: 8.w),
                      width: 52.w,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
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
                              fontSize: 10.sp,
                              fontFamily: AppTextStyles.bodyFont,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            date.day.toString(),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTextStyles.bodyFont,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            DateFormat('MMM').format(date),
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontFamily: AppTextStyles.bodyFont,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
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
          ),

          SizedBox(height: 1.h),

          // ── Sport filter ───────────────────────────────────────
          if (widget.turf.sports.length > 1)
            Container(
              color: Colors.white,
              padding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Row(
                children: widget.turf.sports.map((sport) {
                  final selected = sport == _selectedSport;
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedSport = sport),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          sport,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: AppTextStyles.bodyFont,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          SizedBox(height: 1.h),

          // ── Legend ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Wrap(
              spacing: 16.w,
              runSpacing: 6.h,
              children: [
                _Legend(color: AppColors.primary, label: 'Available'),
                _Legend(color: Colors.blue, label: 'Booked'),
                _Legend(color: Colors.orange, label: 'Blocked'),
                _Legend(color: AppColors.grey, label: 'Past'),
              ],
            ),
          ),

          SizedBox(height: 8.h),

          // ── Slot grid ──────────────────────────────────────────
          slotsAsync.when(
            loading: () => Padding(
              padding: EdgeInsets.all(16.w),
              child: Shimmer.fromColors(
                baseColor: Colors.grey[200]!,
                highlightColor: Colors.grey[100]!,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8.w,
                    mainAxisSpacing: 8.h,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: 16,
                  itemBuilder: (_, __) => Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Could not load slots')),
            ),
            data: (allSlots) {
              final slots = allSlots
                  .where((s) => s.sport == _selectedSport)
                  .toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));

              if (slots.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(32.w),
                  child: Center(
                    child: Text(
                      'No slots seeded for this date',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.all(16.w),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8.w,
                    mainAxisSpacing: 8.h,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (_, i) =>
                      _SlotTile(
                    slot: slots[i],
                    isPast: _isPast(slots[i].startTime),
                    onTapAvailable: () => _confirmLock(slots[i]),
                    onTapOwnerBlocked: () => _confirmUnlock(slots[i]),
                  ),
                ),
              );
            },
          ),

          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final Slot slot;
  final bool isPast;
  final VoidCallback onTapAvailable;
  final VoidCallback onTapOwnerBlocked;

  const _SlotTile({
    required this.slot,
    required this.isPast,
    required this.onTapAvailable,
    required this.onTapOwnerBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnerBlocked =
        slot.isLocked && slot.lockedBy == SlotLock.owner;
    final isAppBooked = slot.bookedCount > 0;
    final isFullyBooked = slot.availableCount <= 0 && !isOwnerBlocked;
    final multiCourt = slot.courtCount > 1;

    Color bgColor;
    Color textColor;
    String? subLabel;
    VoidCallback? onTap;

    if (isPast) {
      bgColor = AppColors.greyLight;
      textColor = AppColors.grey;
    } else if (isOwnerBlocked) {
      bgColor = Colors.orange.withValues(alpha: 0.15);
      textColor = Colors.orange;
      subLabel = 'Blocked';
      onTap = onTapOwnerBlocked;
    } else if (isFullyBooked) {
      bgColor = Colors.blue.withValues(alpha: 0.12);
      textColor = Colors.blue;
      subLabel = multiCourt ? 'Full' : 'Booked';
    } else if (isAppBooked && multiCourt) {
      // Partially booked multi-court
      bgColor = AppColors.primaryLight;
      textColor = AppColors.primary;
      subLabel =
          '${slot.availableCount}/${slot.courtCount}';
      onTap = onTapAvailable;
    } else {
      // Fully available
      bgColor = AppColors.primaryLight;
      textColor = AppColors.primary;
      if (multiCourt) {
        subLabel =
            '${slot.courtCount}/${slot.courtCount}';
      }
      onTap = onTapAvailable;
    }

    // Coaching indicator
    String? coachingTag;
    if (slot.coachingReserved > 0 && !isPast) {
      coachingTag = slot.coachingReserved == slot.courtCount
          ? 'Coach'
          : '+${slot.coachingReserved}C';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: onTap != null
                ? textColor.withValues(alpha: 0.4)
                : bgColor,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              TurfDateUtils.formatHour(slot.startTime),
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                fontFamily: AppTextStyles.bodyFont,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (subLabel != null) ...[
              SizedBox(height: 2.h),
              Text(
                subLabel,
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTextStyles.bodyFont,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
            ],
            if (coachingTag != null) ...[
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  coachingTag,
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber[800],
                    fontFamily: AppTextStyles.bodyFont,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        SizedBox(width: 5.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Turf Details ──────────────────────────────────────────────────────────────

class _TurfDetails extends StatelessWidget {
  final Turf turf;
  final IconData Function(String) amenityIcon;

  const _TurfDetails({required this.turf, required this.amenityIcon});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Photo ──────────────────────────────────────────────
          if (turf.photos.isNotEmpty)
            CachedNetworkImage(
              imageUrl: turf.photos.first,
              height: 200.h,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 200.h,
                color: AppColors.primaryDark,
                child: Center(
                  child: Icon(Icons.sports,
                      size: 40.sp,
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 200.h,
                color: AppColors.primaryDark,
                child: Center(
                  child: Icon(Icons.image_not_supported,
                      size: 40.sp,
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
            ),

          // ── Turf info ──────────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        turf.name,
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTextStyles.bodyFont,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: turf.isActive
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        turf.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTextStyles.bodyFont,
                          color: turf.isActive
                              ? AppColors.primary
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8.h),

                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14.sp, color: AppColors.textSecondary),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        '${turf.area} · ${turf.address}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                          fontFamily: AppTextStyles.bodyFont,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),

                // ── Quick info cards ───────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Price',
                        value: '${AppFormat.price(turf.pricePerHour)}/hr',
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.schedule_rounded,
                        label: 'Hours',
                        value:
                            '${TurfDateUtils.formatHour(turf.openTime)} – ${TurfDateUtils.formatHour(turf.closeTime)}',
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.star_rounded,
                        label: 'Rating',
                        value:
                            turf.rating > 0 ? '${turf.rating}' : 'New',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),

                // ── Sports ─────────────────────────────────────────
                Text(
                  'Sports',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTextStyles.bodyFont,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8.w,
                  children: turf.sports
                      .map((s) => Chip(
                            label: Text(s),
                            labelStyle: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              fontFamily: AppTextStyles.bodyFont,
                              color: AppColors.primary,
                            ),
                            backgroundColor: AppColors.primaryLight,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                          ))
                      .toList(),
                ),

                // ── Court counts ──────────────────────────────────
                if (turf.courtCounts.isNotEmpty) ...[
                  SizedBox(height: 24.h),
                  Text(
                    'Courts',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTextStyles.bodyFont,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Wrap(
                    spacing: 12.w,
                    runSpacing: 8.h,
                    children: turf.courtCounts.entries.map((e) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${e.key}: ${e.value} court${e.value > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontFamily: AppTextStyles.bodyFont,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                SizedBox(height: 24.h),

                // ── Amenities ──────────────────────────────────────
                if (turf.amenities.isNotEmpty) ...[
                  Text(
                    'Amenities',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTextStyles.bodyFont,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Wrap(
                    spacing: 12.w,
                    runSpacing: 12.h,
                    children: turf.amenities
                        .map((a) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32.w,
                                  height: 32.w,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius:
                                        BorderRadius.circular(8.r),
                                  ),
                                  child: Icon(amenityIcon(a),
                                      size: 16.sp,
                                      color: AppColors.primary),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  a,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontFamily: AppTextStyles.bodyFont,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ))
                        .toList(),
                  ),
                ],

                SizedBox(height: 32.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20.sp, color: AppColors.primary),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              fontFamily: AppTextStyles.bodyFont,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.textSecondary,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerTurf extends StatelessWidget {
  const _ShimmerTurf();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          Container(height: 200.h, color: Colors.white),
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 24.h, width: 200.w, color: Colors.white),
                SizedBox(height: 12.h),
                Container(
                    height: 16.h, width: 150.w, color: Colors.white),
                SizedBox(height: 24.h),
                Row(
                  children: List.generate(
                    3,
                    (_) => Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: 10.w),
                        height: 70.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
