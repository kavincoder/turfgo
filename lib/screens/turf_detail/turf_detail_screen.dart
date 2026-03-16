import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/constants.dart';
import '../../models/turf.dart';
import '../slot_selection/slot_selection_screen.dart';

class _Review {
  final String name;
  final String initials;
  final double rating;
  final String comment;
  final String date;

  const _Review({
    required this.name,
    required this.initials,
    required this.rating,
    required this.comment,
    required this.date,
  });
}

const _mockReviews = [
  _Review(
    name: 'Arjun Mehta',
    initials: 'AM',
    rating: 5.0,
    comment:
        'Amazing turf! Well maintained and great floodlights. Will definitely book again.',
    date: 'Mar 10, 2026',
  ),
  _Review(
    name: 'Priya Sharma',
    initials: 'PS',
    rating: 4.5,
    comment:
        'Good surface and facilities. Parking was a bit cramped but overall great experience.',
    date: 'Mar 5, 2026',
  ),
  _Review(
    name: 'Rahul Nair',
    initials: 'RN',
    rating: 4.0,
    comment:
        'Decent place to play. Staff was helpful and the changing rooms were clean.',
    date: 'Feb 28, 2026',
  ),
];

const _amenityIcons = {
  'Parking': Icons.local_parking_rounded,
  'Floodlights': Icons.light_mode_rounded,
  'Changing Room': Icons.checkroom_rounded,
  'Drinking Water': Icons.water_drop_rounded,
  'First Aid': Icons.medical_services_rounded,
  'Cafeteria': Icons.restaurant_rounded,
};

class TurfDetailScreen extends StatelessWidget {
  final Turf turf;

  const TurfDetailScreen({super.key, required this.turf});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final imageUrl = turf.photos.isNotEmpty ? turf.photos[0] : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Photo header
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            height: 300.h,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _photoPlaceholder(context),
                            errorWidget: (_, __, ___) =>
                                _photoPlaceholder(context),
                          )
                        : _photoPlaceholder(context),
                    // Bottom gradient
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 80.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Back button
                    Positioned(
                      top: topPad + 8.h,
                      left: 16.w,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(Icons.arrow_back,
                              size: 20.sp,
                              color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    // Rating badge
                    Positioned(
                      top: topPad + 8.h,
                      right: 16.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                color: const Color(0xFFF59E0B),
                                size: 18.sp),
                            SizedBox(width: 4.w),
                            Text(
                              turf.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                fontFamily: AppTextStyles.bodyFont,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Turf info
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        turf.name,
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTextStyles.bodyFont,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16.sp,
                              color: AppColors.textSecondary),
                          SizedBox(width: 4.w),
                          Text(
                            turf.area,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textSecondary,
                              fontFamily: AppTextStyles.bodyFont,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: turf.sports.map((sport) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 14.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              sport,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                                fontFamily: AppTextStyles.bodyFont,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 20.h),
                      const Divider(color: AppColors.border, height: 1),
                      SizedBox(height: 20.h),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '₹${turf.pricePerHour.toInt()}',
                              style: TextStyle(
                                fontSize: 26.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                fontFamily: AppTextStyles.bodyFont,
                              ),
                            ),
                            TextSpan(
                              text: '/hour',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textSecondary,
                                fontFamily: AppTextStyles.bodyFont,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 12.h)),

              // Amenities
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amenities',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTextStyles.bodyFont,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Wrap(
                        spacing: 12.w,
                        runSpacing: 16.h,
                        children: turf.amenities.map((amenity) {
                          final icon = _amenityIcons[amenity] ??
                              Icons.check_circle_outline;
                          return SizedBox(
                            width: (MediaQuery.of(context).size.width -
                                    40.w -
                                    36.w) /
                                3,
                            child: Column(
                              children: [
                                Container(
                                  width: 52.w,
                                  height: 52.w,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius:
                                        BorderRadius.circular(14.r),
                                  ),
                                  child: Icon(icon,
                                      size: 24.sp,
                                      color: AppColors.primary),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  amenity,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontFamily: AppTextStyles.bodyFont,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 12.h)),

              // Reviews
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Reviews',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTextStyles.bodyFont,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.star_rounded,
                                    color: const Color(0xFFF59E0B),
                                    size: 14.sp),
                                SizedBox(width: 3.w),
                                Text(
                                  turf.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: AppTextStyles.bodyFont,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      ..._mockReviews
                          .map((review) => _ReviewTile(review: review)),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                  padding: EdgeInsets.only(bottom: 90.h + bottomPad)),
            ],
          ),

          // Bottom Book Now bar
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SlotSelectionScreen(turf: turf),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 54.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 0,
                  textStyle: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTextStyles.bodyFont,
                  ),
                ),
                child: const Text('Book Now'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder(BuildContext context) => Container(
        height: 300.h,
        color: const Color(0xFF1B4332),
        child: Center(
          child: Icon(
            Icons.sports_soccer,
            size: 64.sp,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      );
}

class _ReviewTile extends StatelessWidget {
  final _Review review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20.r,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  review.initials,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontFamily: AppTextStyles.bodyFont,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTextStyles.bodyFont,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < review.rating.floor()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 14.sp,
                            color: const Color(0xFFF59E0B),
                          );
                        }),
                        SizedBox(width: 6.w),
                        Text(
                          review.date,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.grey,
                            fontFamily: AppTextStyles.bodyFont,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            review.comment,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
              fontFamily: AppTextStyles.bodyFont,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12.h),
          const Divider(color: AppColors.border, height: 1),
        ],
      ),
    );
  }
}
