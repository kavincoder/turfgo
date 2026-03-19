import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../models/turf.dart';
import '../../providers/owner_provider.dart';

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

          // Show the first turf (most owners have 1)
          final turf = turfs.first;
          return _TurfDetails(turf: turf, amenityIcon: AmenityUtils.icon);
        },
      ),
    );
  }
}

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
          // ── Photo ──────────────────────────────────────────
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

          // ── Turf info ──────────────────────────────────────
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
                          color:
                              turf.isActive ? AppColors.primary : AppColors.error,
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

                // ── Quick info cards ─────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Price',
                        value: '₹${turf.pricePerHour.toInt()}/hr',
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
                        value: turf.rating > 0 ? '${turf.rating}' : 'New',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),

                // ── Sports ───────────────────────────────────
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

                SizedBox(height: 24.h),

                // ── Amenities ────────────────────────────────
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
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Icon(amenityIcon(a),
                                      size: 16.sp, color: AppColors.primary),
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
