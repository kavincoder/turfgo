import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../models/turf.dart';
import '../../providers/turf_provider.dart';
import '../../providers/user_provider.dart';
import '../turf_detail/turf_detail_screen.dart';

const _kDefaultCityId = 'city_madurai';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  String _selectedSport = 'All';
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Turf> _filter(List<Turf> turfs) {
    return turfs.where((t) {
      final matchesSport =
          _selectedSport == 'All' || t.sports.contains(_selectedSport);
      final matchesQuery = _query.isEmpty ||
          t.name.toLowerCase().contains(_query.toLowerCase()) ||
          t.area.toLowerCase().contains(_query.toLowerCase());
      return matchesSport && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cityId = ref.watch(currentUserProvider).valueOrNull?.cityId ??
        _kDefaultCityId;
    final turfsAsync = ref.watch(turfsProvider(cityId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Explore',
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
          // Search + filter (sticky)
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
            child: Column(
              children: [
                Container(
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontFamily: AppTextStyles.bodyFont,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search turfs or areas...',
                      prefixIcon: Icon(Icons.search,
                          color: AppColors.grey, size: 20.sp),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(Icons.close,
                                  color: AppColors.grey, size: 18.sp),
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                      hintStyle: TextStyle(
                        color: AppColors.grey,
                        fontSize: 15.sp,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: Sports.filterList.map((sport) {
                      final isSelected = sport == _selectedSport;
                      return Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedSport = sport),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: EdgeInsets.symmetric(
                                horizontal: 18.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(24.r),
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
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppTextStyles.bodyFont,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),

          // Results
          Expanded(
            child: turfsAsync.when(
              loading: () => ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(20.w),
                itemCount: 4,
                itemBuilder: (_, __) => Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: const _ExploreTurfCardSkeleton(),
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Could not load turfs.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15.sp,
                    fontFamily: AppTextStyles.bodyFont,
                  ),
                ),
              ),
              data: (turfs) {
                final filtered = _filter(turfs);
                if (filtered.isEmpty) {
                  return _EmptyState(
                    query: _query,
                    sport: _selectedSport,
                    noTurfsInCity: turfs.isEmpty,
                    onClear: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                        _selectedSport = 'All';
                      });
                    },
                  );
                }
                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(20.w),
                  children: [
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? 'turf' : 'turfs'} found',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    ...filtered.map(
                      (t) => Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: _ExploreTurfCard(
                          turf: t,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TurfDetailScreen(turf: t),
                            ),
                          ),
                        ),
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

// ---------------------------------------------------------------------------
// Explore turf card
// ---------------------------------------------------------------------------

class _ExploreTurfCard extends StatelessWidget {
  final Turf turf;
  final VoidCallback onTap;

  const _ExploreTurfCard({required this.turf, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = turf.photos.isNotEmpty ? turf.photos[0] : '';

    return GestureDetector(
      onTap: onTap,
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
              borderRadius:
                  BorderRadius.horizontal(left: Radius.circular(16.r)),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 110.w,
                      height: 110.h,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            turf.name,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTextStyles.bodyFont,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                color: AppColors.warning,
                                size: 14.sp),
                            SizedBox(width: 2.w),
                            Text(
                              turf.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                fontFamily: AppTextStyles.bodyFont,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13.sp,
                            color: AppColors.textSecondary),
                        SizedBox(width: 3.w),
                        Text(
                          turf.area,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                            fontFamily: AppTextStyles.bodyFont,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 4.w,
                      children: turf.sports.map((s) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              fontFamily: AppTextStyles.bodyFont,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '₹${turf.pricePerHour.toInt()}/hr',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 110.w,
        height: 110.h,
        color: AppColors.primaryDark,
        child: Icon(Icons.sports_soccer,
            size: 28.sp,
            color: Colors.white.withValues(alpha: 0.25)),
      );
}

// ---------------------------------------------------------------------------
// Shimmer skeleton
// ---------------------------------------------------------------------------

class _ExploreTurfCardSkeleton extends StatelessWidget {
  const _ExploreTurfCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 110.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Container(
              width: 110.w,
              height: 110.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(16.r)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        height: 14.h,
                        width: 140.w,
                        color: Colors.grey[300]),
                    SizedBox(height: 8.h),
                    Container(
                        height: 12.h,
                        width: 90.w,
                        color: Colors.grey[300]),
                    SizedBox(height: 10.h),
                    Container(
                        height: 12.h,
                        width: 60.w,
                        color: Colors.grey[300]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final String query;
  final String sport;
  final bool noTurfsInCity;
  final VoidCallback onClear;

  const _EmptyState({
    required this.query,
    required this.sport,
    required this.noTurfsInCity,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isFiltering = query.isNotEmpty || sport != 'All';

    final icon = noTurfsInCity
        ? Icons.location_city_rounded
        : Icons.search_off_rounded;
    final title = noTurfsInCity
        ? 'No turfs in your city yet'
        : 'No turfs found';
    final subtitle = noTurfsInCity
        ? 'We\'re onboarding turfs near you. Check back soon!'
        : 'Try a different search or sport filter.';

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38.sp, color: AppColors.primary),
            ),
            SizedBox(height: 20.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                fontFamily: AppTextStyles.bodyFont,
              ),
              textAlign: TextAlign.center,
            ),
            if (isFiltering && !noTurfsInCity) ...[
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: onClear,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                  textStyle: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTextStyles.bodyFont,
                  ),
                ),
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
