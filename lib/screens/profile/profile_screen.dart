import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../models/owner_request.dart';
import '../../providers/owner_request_provider.dart';
import '../../providers/user_provider.dart';
import '../owner_registration/owner_registration_screen.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'Sign Out?',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'You will need to log in again to book turfs.',
          style: TextStyle(
            fontSize: 14.sp,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: AppTextStyles.bodyFont,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                fontFamily: AppTextStyles.bodyFont,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) context.go('/login');
    }
  }

  void _showHelpSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 40.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Help & Support',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 16.h),
            _SupportRow(
              icon: Icons.chat_rounded,
              label: 'WhatsApp Us',
              value: '+91 98765 43210',
            ),
            SizedBox(height: 12.h),
            _SupportRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: 'support@turfgo.in',
            ),
            SizedBox(height: 12.h),
            _SupportRow(
              icon: Icons.access_time_rounded,
              label: 'Support Hours',
              value: 'Mon–Sat, 9 AM – 7 PM',
            ),
            SizedBox(height: 16.h),
            Text(
              'We typically respond within 2 hours.',
              style: TextStyle(
                fontSize: 12.sp,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 40.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTextStyles.bodyFont,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Last updated: March 2026',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontFamily: AppTextStyles.bodyFont,
                  color: AppColors.grey,
                ),
              ),
              SizedBox(height: 16.h),
              _PolicySection(
                title: 'Data We Collect',
                body:
                    'We collect your phone number for authentication, your name (optional), and booking history to provide our services.',
              ),
              _PolicySection(
                title: 'How We Use Your Data',
                body:
                    'Your data is used solely to facilitate turf bookings, send booking confirmations, and improve the app experience. We do not sell your data to third parties.',
              ),
              _PolicySection(
                title: 'Payments',
                body:
                    'Payments are processed securely by Razorpay. TurfGo does not store your card or bank details.',
              ),
              _PolicySection(
                title: 'Data Security',
                body:
                    'All data is encrypted in transit and stored securely on Google Firebase servers in India.',
              ),
              _PolicySection(
                title: 'Contact',
                body:
                    'For privacy concerns, email us at privacy@turfgo.in or WhatsApp +91 98765 43210.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 40.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Terms of Service',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTextStyles.bodyFont,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Last updated: March 2026',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontFamily: AppTextStyles.bodyFont,
                  color: AppColors.grey,
                ),
              ),
              SizedBox(height: 16.h),
              _PolicySection(
                title: 'Acceptance',
                body:
                    'By using TurfGo, you agree to these terms. If you do not agree, please uninstall the app.',
              ),
              _PolicySection(
                title: 'Bookings & Payments',
                body:
                    'All bookings are subject to slot availability. Payments are non-refundable unless a booking is cancelled by the turf owner. TurfGo charges an 8% platform fee on all bookings.',
              ),
              _PolicySection(
                title: 'User Conduct',
                body:
                    'Users must arrive on time for bookings. Repeated no-shows may result in account suspension. Any misuse of the platform is grounds for termination.',
              ),
              _PolicySection(
                title: 'Cancellations',
                body:
                    'Cancellation requests must be submitted through the app. Refund eligibility depends on how far in advance the cancellation is made.',
              ),
              _PolicySection(
                title: 'Liability',
                body:
                    'TurfGo is a booking platform and is not liable for injuries, disputes, or losses that occur at turf facilities.',
              ),
              _PolicySection(
                title: 'Contact',
                body:
                    'For terms-related queries, email legal@turfgo.in or WhatsApp +91 98765 43210.',
              ),
            ],
          ),
        ),
      ),
    );
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
          onHelpSupport: _showHelpSupport,
          onPrivacyPolicy: _showPrivacyPolicy,
          onTermsOfService: _showTermsOfService,
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
  final void Function(BuildContext) onHelpSupport;
  final void Function(BuildContext) onPrivacyPolicy;
  final void Function(BuildContext) onTermsOfService;

  const _Body({
    required this.user,
    required this.phone,
    required this.initials,
    required this.onMyBookings,
    required this.onEditName,
    required this.onSignOut,
    required this.onHelpSupport,
    required this.onPrivacyPolicy,
    required this.onTermsOfService,
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

          // ── Owner registration — visible to everyone except admins ──────────
          // Owners see their request status; players see the apply CTA;
          // null users (doc not yet created) also see the CTA.
          if (user?.role != UserRole.admin) _OwnerRegistrationBanner(),

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
                  onTap: () => onHelpSupport(context),
                ),
                const _Divider(),
                _MenuItem(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => onPrivacyPolicy(context),
                ),
                const _Divider(),
                _MenuItem(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () => onTermsOfService(context),
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

class _SupportRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SupportRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20.sp, color: AppColors.primary),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.grey,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              fontFamily: AppTextStyles.bodyFont,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            body,
            style: TextStyle(
              fontSize: 13.sp,
              fontFamily: AppTextStyles.bodyFont,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerRegistrationBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestAsync = ref.watch(userOwnerRequestProvider);

    return requestAsync.when(
      loading: () => _buildCTA(context),
      error: (_, __) => _buildCTA(context),
      data: (request) {
        if (request == null) return _buildCTA(context);
        return _buildStatus(context, request);
      },
    );
  }

  Widget _buildCTA(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OwnerRegistrationScreen(),
        ),
      ),
      child: Container(
        margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryGradient],
          ),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(Icons.store_rounded,
                  size: 22.sp, color: Colors.white),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Own a turf?',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTextStyles.bodyFont,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Register as a turf owner and start earning',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontFamily: AppTextStyles.bodyFont,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 16.sp, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus(BuildContext context, OwnerRequest request) {
    final color = _textColor(request.status);
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _bgColor(request.status),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _borderColor(request.status)),
      ),
      child: Row(
        children: [
          Icon(_icon(request.status), size: 22.sp, color: color),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(request.status),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTextStyles.bodyFont,
                    color: color,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _subtitle(request),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontFamily: AppTextStyles.bodyFont,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _bgColor(String status) {
    switch (status) {
      case RequestStatus.pending:
        return const Color(0xFFFFF8E1);
      case RequestStatus.approved:
        return AppColors.primaryLight;
      case RequestStatus.rejected:
        return const Color(0xFFFEE2E2);
      default:
        return AppColors.surface;
    }
  }

  Color _borderColor(String status) {
    switch (status) {
      case RequestStatus.pending:
        return const Color(0xFFFFE082);
      case RequestStatus.approved:
        return AppColors.primary.withValues(alpha: 0.3);
      case RequestStatus.rejected:
        return AppColors.error.withValues(alpha: 0.3);
      default:
        return AppColors.border;
    }
  }

  Color _textColor(String status) {
    switch (status) {
      case RequestStatus.pending:
        return const Color(0xFFF57F17);
      case RequestStatus.approved:
        return AppColors.primary;
      case RequestStatus.rejected:
        return AppColors.error;
      default:
        return AppColors.textPrimary;
    }
  }

  IconData _icon(String status) {
    switch (status) {
      case RequestStatus.pending:
        return Icons.hourglass_top_rounded;
      case RequestStatus.approved:
        return Icons.check_circle_rounded;
      case RequestStatus.rejected:
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline;
    }
  }

  String _title(String status) {
    switch (status) {
      case RequestStatus.pending:
        return 'Request Under Review';
      case RequestStatus.approved:
        return 'Request Approved!';
      case RequestStatus.rejected:
        return 'Request Rejected';
      default:
        return status;
    }
  }

  String _subtitle(OwnerRequest req) {
    switch (req.status) {
      case RequestStatus.pending:
        return 'We\'re reviewing "${req.turfName}". Hang tight!';
      case RequestStatus.approved:
        return 'Restart the app to access your owner dashboard.';
      case RequestStatus.rejected:
        return req.rejectionReason ?? 'Please try again with updated info.';
      default:
        return '';
    }
  }
}
