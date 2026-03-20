import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../models/turf.dart';
import '../../providers/turf_provider.dart';
import '../../providers/user_provider.dart';
import '../turf_detail/turf_detail_screen.dart';

/// Fallback city when user has no cityId set or location cannot be determined.
const _kDefaultCityId = 'city_madurai';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _locationText = 'Detecting...';
  String _selectedSport = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationText = 'Madurai');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _locationText = 'Madurai');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationText = 'Madurai');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final city = p.locality ?? p.subAdministrativeArea ?? '';
        setState(() {
          _locationText = city.isNotEmpty ? city : 'Madurai';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationText = 'Madurai');
    }
  }

  List<Turf> _filter(List<Turf> turfs) {
    var result = turfs;
    // Filter by selected sport
    if (_selectedSport != 'All') {
      result = result.where((t) => t.sports.contains(_selectedSport)).toList();
    }
    // Filter by search query (name or area, case-insensitive)
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where((t) =>
              t.name.toLowerCase().contains(q) ||
              t.area.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    // Use city from user profile; fall back to default if not yet loaded
    final userAsync = ref.watch(currentUserProvider);
    final cityId = userAsync.valueOrNull?.cityId.isNotEmpty == true
        ? userAsync.valueOrNull!.cityId
        : _kDefaultCityId;
    final turfsAsync = ref.watch(turfsProvider(cityId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(turfsProvider(cityId)),
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Green header
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.primary,
              padding: EdgeInsets.fromLTRB(20.w, topPad + 16.h, 20.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13.sp,
                      fontFamily: AppTextStyles.bodyFont,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          color: Colors.white, size: 18.sp),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          _locationText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTextStyles.bodyFont,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontFamily: AppTextStyles.bodyFont,
                        color: AppColors.textPrimary,
                      ),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search by turf name or area',
                        prefixIcon: Icon(Icons.search,
                            color: AppColors.grey, size: 22.sp),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: Icon(Icons.close,
                                    color: AppColors.grey, size: 20.sp),
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14.h),
                        hintStyle: TextStyle(
                          color: AppColors.grey,
                          fontSize: 15.sp,
                          fontFamily: AppTextStyles.bodyFont,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sport filter chips
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: Sports.filterList.map((sport) {
                    final isSelected = sport == _selectedSport;
                    return Padding(
                      padding: EdgeInsets.only(right: 10.w),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedSport = sport),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(
                              horizontal: 20.w, vertical: 10.h),
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
              ),
            ),
          ),



          // Featured Turfs heading
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
              child: Text(
                'Featured Turfs',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTextStyles.bodyFont,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          // Turf list
          turfsAsync.when(
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                  child: const _TurfCardSkeleton(),
                ),
                childCount: 3,
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 40.h),
                child: Center(
                  child: Text(
                    'Could not load turfs. Pull down to retry.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15.sp,
                      fontFamily: AppTextStyles.bodyFont,
                    ),
                  ),
                ),
              ),
            ),
            data: (turfs) {
              final filtered = _filter(turfs);
              if (filtered.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40.h),
                    child: Center(
                      child: Text(
                        'No turfs found for $_selectedSport',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15.sp,
                          fontFamily: AppTextStyles.bodyFont,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding:
                        EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                    child: _TurfCard(turf: filtered[index]),
                  ),
                  childCount: filtered.length,
                ),
              );
            },
          ),

          SliverPadding(padding: EdgeInsets.only(bottom: 8.h)),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Turf card
// ---------------------------------------------------------------------------

class _TurfCard extends StatelessWidget {
  final Turf turf;
  const _TurfCard({required this.turf});

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        turf.photos.isNotEmpty ? turf.photos[0] : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(16.r)),
            child: Stack(
              children: [
                imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 200.h,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _photoPlaceholder(),
                        errorWidget: (_, __, ___) =>
                            _photoPlaceholder(),
                      )
                    : _photoPlaceholder(),
                Positioned(
                  top: 12.h,
                  right: 12.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            color: AppColors.warning,
                            size: 16.sp),
                        SizedBox(width: 4.w),
                        Text(
                          turf.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13.sp,
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
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  turf.name,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTextStyles.bodyFont,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 16.sp,
                        color: AppColors.textSecondary),
                    SizedBox(width: 4.w),
                    Text(
                      turf.area,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '₹${turf.pricePerHour.toInt()}',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontFamily: AppTextStyles.bodyFont,
                            ),
                          ),
                          TextSpan(
                            text: '/hour',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppColors.textSecondary,
                              fontFamily: AppTextStyles.bodyFont,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TurfDetailScreen(turf: turf),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: Size(0, 44.h),
                        padding:
                            EdgeInsets.symmetric(horizontal: 24.w),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24.r),
                        ),
                        elevation: 0,
                        textStyle: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTextStyles.bodyFont,
                        ),
                      ),
                      child: const Text('Book Now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() => Container(
        height: 200.h,
        color: AppColors.primaryDark,
        child: Center(
          child: Icon(
            Icons.sports_soccer,
            size: 52.sp,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Shimmer skeleton card
// ---------------------------------------------------------------------------

class _TurfCardSkeleton extends StatelessWidget {
  const _TurfCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16.r)),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 18.h,
                      width: 180.w,
                      color: Colors.grey[300]),
                  SizedBox(height: 10.h),
                  Container(
                      height: 13.h,
                      width: 120.w,
                      color: Colors.grey[300]),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                          height: 18.h,
                          width: 80.w,
                          color: Colors.grey[300]),
                      Container(
                        height: 44.h,
                        width: 110.w,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(24.r),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
