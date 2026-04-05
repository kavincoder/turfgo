import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../models/turf.dart';
import '../../providers/admin_provider.dart';

class AdminTurfsScreen extends ConsumerWidget {
  const AdminTurfsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turfsAsync = ref.watch(allTurfsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Manage Turfs',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: turfsAsync.when(
        loading: () => const _ShimmerList(),
        error: (_, __) =>
            const Center(child: Text('Something went wrong')),
        data: (turfs) {
          if (turfs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stadium_outlined,
                      size: 48.sp, color: AppColors.grey),
                  SizedBox(height: 12.h),
                  Text(
                    'No turfs registered yet',
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

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: turfs.length,
            itemBuilder: (_, i) => _TurfCard(turf: turfs[i]),
          );
        },
      ),
    );
  }
}

class _TurfCard extends ConsumerWidget {
  final Turf turf;
  const _TurfCard({required this.turf});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Turf photo
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: turf.photos.isNotEmpty
                    ? Image.network(
                        turf.photos.first,
                        width: 56.w,
                        height: 56.w,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      turf.name,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTextStyles.bodyFont,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${turf.area} · ₹${turf.pricePerHour.toInt()}/hr',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Wrap(
                      spacing: 6.w,
                      children: turf.sports
                          .map((s) => Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  s,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: AppTextStyles.bodyFont,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              // Active toggle
              CupertinoSwitch(
                value: turf.isActive,
                activeTrackColor: AppColors.primary,
                onChanged: (val) {
                  ref
                      .read(adminRepositoryProvider)
                      .toggleTurfActive(turf.id, val);
                },
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // Info row
          Row(
            children: [
              Icon(Icons.star_rounded,
                  size: 14.sp, color: AppColors.warning),
              SizedBox(width: 4.w),
              Text(
                turf.rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTextStyles.bodyFont,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 16.w),
              Icon(Icons.access_time_rounded,
                  size: 14.sp, color: AppColors.textSecondary),
              SizedBox(width: 4.w),
              Text(
                '${turf.openTime} – ${turf.closeTime}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  fontFamily: AppTextStyles.bodyFont,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: (turf.isActive ? AppColors.primary : AppColors.error)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
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
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56.w,
      height: 56.w,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Icon(Icons.stadium_rounded, size: 24.sp, color: AppColors.grey),
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
        padding: EdgeInsets.all(16.w),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          margin: EdgeInsets.only(bottom: 12.h),
          height: 120.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      ),
    );
  }
}
