import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants.dart';
import '../../models/owner_request.dart';
import '../../providers/owner_request_provider.dart';
import '../../providers/user_provider.dart';

class OwnerRegistrationScreen extends ConsumerStatefulWidget {
  const OwnerRegistrationScreen({super.key});

  @override
  ConsumerState<OwnerRegistrationScreen> createState() =>
      _OwnerRegistrationScreenState();
}

class _OwnerRegistrationScreenState
    extends ConsumerState<OwnerRegistrationScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _submitting = false;

  // Step 1 — Basic info
  final _turfNameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Step 2 — Sports & price
  final List<String> _selectedSports = [];
  final _priceCtrl = TextEditingController();

  // Step 3 — Hours
  String _openTime = '06:00';
  String _closeTime = '22:00';

  // Step 4 — Amenities
  final List<String> _selectedAmenities = [];

  // Step 5 — Photos
  final List<File> _photos = [];
  final _picker = ImagePicker();

  // Sports list sourced from constants — single source of truth
  static const _allSports = Sports.all;
  static const _timeSlots = [
    '05:00', '06:00', '07:00', '08:00', '09:00', '10:00',
    '11:00', '12:00', '13:00', '14:00', '15:00', '16:00',
    '17:00', '18:00', '19:00', '20:00', '21:00', '22:00',
    '23:00', '00:00',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _turfNameCtrl.dispose();
    _areaCtrl.dispose();
    _addressCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _turfNameCtrl.text.trim().isNotEmpty &&
            _areaCtrl.text.trim().isNotEmpty &&
            _addressCtrl.text.trim().isNotEmpty;
      case 1:
        final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
        return _selectedSports.isNotEmpty &&
            _priceCtrl.text.trim().isNotEmpty &&
            price > 0 &&
            price <= 99999;
      case 2:
        return true; // defaults are valid
      case 3:
        return true; // amenities optional
      case 4:
        return _photos.isNotEmpty;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickPhotos() async {
    final images = await _picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (images.isNotEmpty) {
      setState(() {
        for (final img in images) {
          if (_photos.length < 5) {
            _photos.add(File(img.path));
          }
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final user = ref.read(currentUserProvider).valueOrNull;
      final repo = ref.read(ownerRequestRepositoryProvider);

      // Upload photos
      final photoUrls = <String>[];
      for (int i = 0; i < _photos.length; i++) {
        final url = await repo.uploadTurfPhoto(
          userId: uid,
          file: _photos[i],
          index: i,
        );
        photoUrls.add(url);
      }

      // Submit request
      final request = OwnerRequest(
        id: '',
        userId: uid,
        userName: user?.name ?? '',
        userPhone: user?.phone ?? '',
        turfName: _turfNameCtrl.text.trim(),
        area: _areaCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        cityId: user?.cityId ?? 'madurai',
        sports: _selectedSports,
        pricePerHour: double.parse(_priceCtrl.text.trim()),
        openTime: _openTime,
        closeTime: _closeTime,
        amenities: _selectedAmenities,
        photos: photoUrls,
        status: RequestStatus.pending,
        createdAt: DateTime.now(),
      );

      await repo.submitRequest(request);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request submitted! We\'ll review it shortly.',
              style: TextStyle(fontFamily: AppTextStyles.bodyFont),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Owner registration error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not submit your request. Please try again.',
              style: TextStyle(fontFamily: AppTextStyles.bodyFont),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatTime(String time24) {
    final h = int.parse(time24.split(':')[0]);
    final period = h < 12 ? 'AM' : 'PM';
    final display = h == 0 ? 12 : h <= 12 ? h : h - 12;
    return '$display:00 $period';
  }

  @override
  Widget build(BuildContext context) {
    final stepLabels = [
      'Turf Info',
      'Sports & Price',
      'Hours',
      'Amenities',
      'Photos',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Register as Owner',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Progress indicator ──────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
            child: Column(
              children: [
                Row(
                  children: List.generate(5, (i) {
                    return Expanded(
                      child: Container(
                        height: 4.h,
                        margin: EdgeInsets.symmetric(horizontal: 2.w),
                        decoration: BoxDecoration(
                          color: i <= _currentStep
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Step ${_currentStep + 1}/5 — ${stepLabels[_currentStep]}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    fontFamily: AppTextStyles.bodyFont,
                  ),
                ),
              ],
            ),
          ),

          // ── Form pages ─────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
                _buildStep5(),
              ],
            ),
          ),

          // ── Bottom buttons ─────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _prevStep,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: Size(0, 50.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        textStyle: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTextStyles.bodyFont,
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) SizedBox(width: 12.w),
                Expanded(
                  flex: _currentStep == 0 ? 1 : 2,
                  child: ElevatedButton(
                    onPressed:
                        (_canProceed && !_submitting) ? _nextStep : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.grey,
                      minimumSize: Size(0, 50.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      textStyle: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                    child: _submitting
                        ? SizedBox(
                            width: 22.w,
                            height: 22.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentStep == 4 ? 'Submit' : 'Next',
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

  // ── Step 1: Basic Info ───────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us about your turf',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              fontFamily: AppTextStyles.bodyFont,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'This info will be shown to players browsing turfs.',
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),
          SizedBox(height: 24.h),
          _buildField('Turf Name', _turfNameCtrl, 'e.g. Greenfield Arena'),
          SizedBox(height: 16.h),
          _buildField('Area / Locality', _areaCtrl, 'e.g. Anna Nagar'),
          SizedBox(height: 16.h),
          _buildField(
              'Full Address', _addressCtrl, 'e.g. 12, Main Road, Anna Nagar',
              maxLines: 2),
        ],
      ),
    );
  }

  // ── Step 2: Sports & Price ──────────────────────────────────
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sports & Pricing',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              fontFamily: AppTextStyles.bodyFont,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Select the sports your turf supports.',
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),
          SizedBox(height: 20.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: _allSports.map((sport) {
              final selected = _selectedSports.contains(sport);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedSports.remove(sport);
                    } else {
                      _selectedSports.add(sport);
                    }
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color:
                        selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    sport,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTextStyles.bodyFont,
                      color:
                          selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 24.h),
          _buildField('Price per Hour (₹)', _priceCtrl, 'e.g. 800',
              keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  // ── Step 3: Hours ───────────────────────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operating Hours',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              fontFamily: AppTextStyles.bodyFont,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Set your turf\'s opening and closing times.',
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),
          SizedBox(height: 24.h),
          _buildTimePicker('Opens at', _openTime, (val) {
            setState(() => _openTime = val);
          }),
          SizedBox(height: 16.h),
          _buildTimePicker('Closes at', _closeTime, (val) {
            setState(() => _closeTime = val);
          }),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18.sp, color: AppColors.primary),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Your turf will be bookable from ${_formatTime(_openTime)} to ${_formatTime(_closeTime)}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.primary,
                      fontFamily: AppTextStyles.bodyFont,
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

  // ── Step 4: Amenities ───────────────────────────────────────
  Widget _buildStep4() {
    return SingleChildScrollView(
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
          SizedBox(height: 6.h),
          Text(
            'Select what your turf offers. This helps attract players.',
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),
          SizedBox(height: 20.h),
          ...List.generate(AmenityUtils.all.length, (i) {
            final amenity = AmenityUtils.all[i];
            final selected = _selectedAmenities.contains(amenity);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedAmenities.remove(amenity);
                  } else {
                    _selectedAmenities.add(amenity);
                  }
                });
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.symmetric(
                    horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      AmenityUtils.icon(amenity),
                      size: 20.sp,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        amenity,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          fontFamily: AppTextStyles.bodyFont,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded,
                          size: 20.sp, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Step 5: Photos ──────────────────────────────────────────
  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Turf Photos',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              fontFamily: AppTextStyles.bodyFont,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Add up to 5 photos of your turf. Good photos get more bookings!',
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),
          SizedBox(height: 20.h),

          // Photo grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8.w,
              crossAxisSpacing: 8.w,
            ),
            itemCount: _photos.length + (_photos.length < 5 ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _photos.length) {
                // Add button
                return GestureDetector(
                  onTap: _pickPhotos,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                          color: AppColors.primary,
                          style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 28.sp, color: AppColors.primary),
                        SizedBox(height: 4.h),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.primary,
                            fontFamily: AppTextStyles.bodyFont,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: Image.file(
                      _photos[i],
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4.h,
                    right: 4.w,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _photos.removeAt(i));
                      },
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close,
                            size: 14.sp, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: 12.h),
          Text(
            '${_photos.length}/5 photos added',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.textSecondary,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            fontFamily: AppTextStyles.bodyFont,
            fontSize: 15.sp,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.grey,
              fontFamily: AppTextStyles.bodyFont,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(
      String label, String current, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: current,
              isExpanded: true,
              icon: Icon(Icons.access_time_rounded,
                  size: 18.sp, color: AppColors.textSecondary),
              style: TextStyle(
                fontSize: 15.sp,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.textPrimary,
              ),
              items: _timeSlots
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(_formatTime(t)),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }
}
