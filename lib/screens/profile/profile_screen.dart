import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../providers/user_provider.dart';

class ProfileScreen extends ConsumerWidget {
  final VoidCallback onMyBookings;

  const ProfileScreen({super.key, required this.onMyBookings});

  String _initials(AppUser? user, String phone) {
    final name = user?.name.trim() ?? '';
    if (name.isNotEmpty) {
      final words = name.split(' ').where((w) => w.isNotEmpty).toList();
      return words.take(2).map((w) => w[0].toUpperCase()).join();
    }
    return phone.length >= 2 ? phone.substring(0, 2) : 'TG';
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String currentName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _EditNameDialog(
        currentName: currentName,
        onSave: (name) =>
            ref.read(userRepositoryProvider).updateName(uid, name),
      ),
    );

    // Force the stream to re-fetch so the updated name shows immediately
    if (context.mounted) ref.invalidate(currentUserProvider);
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final rawPhone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    final phone =
        rawPhone.startsWith('+91') ? rawPhone.substring(3) : rawPhone;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) =>
            const Center(child: Text('Could not load profile')),
        data: (user) => _Body(
          user: user,
          phone: phone,
          initials: _initials(user, phone),
          onMyBookings: onMyBookings,
          onEditName: (ctx, ref) =>
              _editName(ctx, ref, user?.name.trim() ?? ''),
          onSignOut: _signOut,
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final AppUser? user;
  final String phone;
  final String initials;
  final VoidCallback onMyBookings;
  final Future<void> Function(BuildContext, WidgetRef) onEditName;
  final Future<void> Function(BuildContext) onSignOut;

  const _Body({
    required this.user,
    required this.phone,
    required this.initials,
    required this.onMyBookings,
    required this.onEditName,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user?.name.trim() ?? '';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          SizedBox(height: 28.h),

          // ── Avatar + name + phone ────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 88.w,
                  height: 88.w,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTextStyles.bodyFont,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                GestureDetector(
                  onTap: () => onEditName(context, ref),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Add your name',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTextStyles.bodyFont,
                          color: name.isNotEmpty
                              ? AppColors.textPrimary
                              : AppColors.grey,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Icon(Icons.edit_outlined,
                          size: 16.sp, color: AppColors.primary),
                    ],
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '+91 $phone',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontFamily: AppTextStyles.bodyFont,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'TurfGo Member',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontFamily: AppTextStyles.bodyFont,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 28.h),

          // ── Menu ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _MenuItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'My Bookings',
                  onTap: onMyBookings,
                ),
                const _Divider(),
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  onTap: () {},
                ),
                const _Divider(),
                _MenuItem(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () {},
                ),
                const _Divider(),
                _MenuItem(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () {},
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // ── Sign out ──────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: OutlinedButton(
              onPressed: () => onSignOut(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: Size(double.infinity, 52.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                textStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTextStyles.bodyFont,
                ),
              ),
              child: const Text('Sign Out'),
            ),
          ),

          SizedBox(height: 40.h),

          Text(
            'TurfGo v1.0.0',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.grey,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),

          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, size: 20.sp, color: AppColors.primary),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  fontFamily: AppTextStyles.bodyFont,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20.sp, color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 72.w),
      child: const Divider(color: AppColors.border, height: 1),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String currentName;
  final Future<void> Function(String) onSave;

  const _EditNameDialog({required this.currentName, required this.onSave});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text(
        'Edit Name',
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          fontFamily: AppTextStyles.bodyFont,
          color: AppColors.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(
              fontFamily: AppTextStyles.bodyFont,
              fontSize: 15.sp,
            ),
            decoration: InputDecoration(
              hintText: 'Your full name',
              hintStyle: TextStyle(
                color: AppColors.grey,
                fontFamily: AppTextStyles.bodyFont,
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.error,
                fontFamily: AppTextStyles.bodyFont,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),
        ),
        TextButton(
          onPressed: _saving
              ? null
              : () async {
                  final name = _ctrl.text.trim();
                  if (name.isEmpty) return;
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    final nav = Navigator.of(context);
                    await widget.onSave(name);
                    nav.pop();
                  } catch (e) {
                    setState(() {
                      _saving = false;
                      _error = 'Failed to save. Please try again.';
                    });
                  }
                },
          child: _saving
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  'Save',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTextStyles.bodyFont,
                  ),
                ),
        ),
      ],
    );
  }
}
