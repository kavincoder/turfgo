import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants.dart';
import '../../models/turf.dart';

class OwnerTurfEditScreen extends StatefulWidget {
  final Turf turf;

  const OwnerTurfEditScreen({super.key, required this.turf});

  @override
  State<OwnerTurfEditScreen> createState() => _OwnerTurfEditScreenState();
}

class _OwnerTurfEditScreenState extends State<OwnerTurfEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _addressCtrl;

  late List<String> _selectedSports;
  late List<String> _selectedAmenities;
  late String _openTime;
  late String _closeTime;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.turf.name);
    _areaCtrl = TextEditingController(text: widget.turf.area);
    _addressCtrl = TextEditingController(text: widget.turf.address);
    _selectedSports = List<String>.from(widget.turf.sports);
    _selectedAmenities = List<String>.from(widget.turf.amenities);
    _openTime = widget.turf.openTime;
    _closeTime = widget.turf.closeTime;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _areaCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSports.isEmpty) {
      setState(() => _error = 'Select at least one sport.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('turfs')
          .doc(widget.turf.id)
          .update({
        'name': _nameCtrl.text.trim(),
        'area': _areaCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'sports': _selectedSports,
        'amenities': _selectedAmenities,
        'openTime': _openTime,
        'closeTime': _closeTime,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Failed to save changes. Please try again.';
      });
    }
  }

  Future<void> _pickTime({required bool isOpen}) async {
    final parts = (isOpen ? _openTime : _closeTime).split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? (isOpen ? 6 : 22),
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isOpen) {
        _openTime = formatted;
      } else {
        _closeTime = formatted;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Turf',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: _saving
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTextStyles.bodyFont,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          children: [
            if (_error != null) ...[
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontFamily: AppTextStyles.bodyFont,
                    color: AppColors.error,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],

            // ── Basic Info ──────────────────────────────────────────
            _SectionLabel(label: 'Basic Info'),
            SizedBox(height: 12.h),

            _Field(
              controller: _nameCtrl,
              label: 'Turf Name',
              hint: 'e.g. RK Nagar Sports Arena',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            SizedBox(height: 14.h),

            _Field(
              controller: _areaCtrl,
              label: 'Area',
              hint: 'e.g. Anna Nagar',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            SizedBox(height: 14.h),

            _Field(
              controller: _addressCtrl,
              label: 'Full Address',
              hint: 'Street, landmark, city',
              maxLines: 2,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            SizedBox(height: 24.h),

            // ── Operating Hours ─────────────────────────────────────
            _SectionLabel(label: 'Operating Hours'),
            SizedBox(height: 12.h),

            Row(
              children: [
                Expanded(
                  child: _TimePicker(
                    label: 'Opens at',
                    time: _openTime,
                    onTap: () => _pickTime(isOpen: true),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _TimePicker(
                    label: 'Closes at',
                    time: _closeTime,
                    onTap: () => _pickTime(isOpen: false),
                  ),
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // ── Sports ──────────────────────────────────────────────
            _SectionLabel(label: 'Sports Available'),
            SizedBox(height: 12.h),

            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: Sports.all.map((sport) {
                final selected = _selectedSports.contains(sport);
                return FilterChip(
                  label: Text(
                    sport,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontFamily: AppTextStyles.bodyFont,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedSports.add(sport);
                      } else {
                        _selectedSports.remove(sport);
                      }
                    });
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 24.h),

            // ── Amenities ───────────────────────────────────────────
            _SectionLabel(label: 'Amenities'),
            SizedBox(height: 8.h),

            ...AmenityUtils.all.map((amenity) {
              final checked = _selectedAmenities.contains(amenity);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Row(
                  children: [
                    Icon(AmenityUtils.icon(amenity),
                        size: 18.sp, color: AppColors.textSecondary),
                    SizedBox(width: 8.w),
                    Text(
                      amenity,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontFamily: AppTextStyles.bodyFont,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                value: checked,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedAmenities.add(amenity);
                    } else {
                      _selectedAmenities.remove(amenity);
                    }
                  });
                },
              );
            }),

            SizedBox(height: 32.h),

            ElevatedButton(
              onPressed: _saving ? null : _save,
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
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Changes'),
            ),

            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
        fontFamily: AppTextStyles.bodyFont,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      textCapitalization: TextCapitalization.words,
      style: TextStyle(
        fontSize: 14.sp,
        fontFamily: AppTextStyles.bodyFont,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontSize: 13.sp,
          fontFamily: AppTextStyles.bodyFont,
          color: AppColors.grey,
        ),
        hintStyle: TextStyle(
          fontSize: 13.sp,
          fontFamily: AppTextStyles.bodyFont,
          color: AppColors.grey,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimePicker({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.grey,
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 16.sp, color: AppColors.primary),
                SizedBox(width: 6.w),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTextStyles.bodyFont,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
