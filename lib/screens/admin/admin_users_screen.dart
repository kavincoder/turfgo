import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../providers/admin_provider.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Manage Users',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: usersAsync.when(
        loading: () => const _ShimmerList(),
        error: (_, __) =>
            const Center(child: Text('Something went wrong')),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 48.sp, color: AppColors.grey),
                  SizedBox(height: 12.h),
                  Text(
                    'No users yet',
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
            itemCount: users.length,
            itemBuilder: (_, i) => _UserCard(user: users[i]),
          );
        },
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final AppUser user;
  const _UserCard({required this.user});

  Color _roleColor(String role) {
    switch (role) {
      case UserRole.admin:
        return AppColors.purple;
      case UserRole.owner:
        return AppColors.blue;
      default:
        return AppColors.primary;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.owner:
        return Icons.store_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _roleColor(user.role);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
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
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(_roleIcon(user.role), size: 22.sp, color: color),
          ),
          SizedBox(width: 12.w),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isNotEmpty ? user.name : 'Unnamed',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTextStyles.bodyFont,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  user.phone,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    fontFamily: AppTextStyles.bodyFont,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Joined ${DateFormat('MMM d, yyyy').format(user.createdAt)}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.grey,
                    fontFamily: AppTextStyles.bodyFont,
                  ),
                ),
              ],
            ),
          ),
          // Role dropdown
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: user.role,
                isDense: true,
                icon: Icon(Icons.arrow_drop_down, size: 18.sp, color: color),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTextStyles.bodyFont,
                  color: color,
                ),
                items: const [
                  DropdownMenuItem(
                      value: UserRole.player, child: Text('Player')),
                  DropdownMenuItem(
                      value: UserRole.owner, child: Text('Owner')),
                  DropdownMenuItem(
                      value: UserRole.admin, child: Text('Admin')),
                ],
                onChanged: (newRole) {
                  if (newRole != null && newRole != user.role) {
                    _confirmRoleChange(context, ref, newRole);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRoleChange(
      BuildContext context, WidgetRef ref, String newRole) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'Change Role',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
          ),
        ),
        content: Text(
          'Change ${user.name.isNotEmpty ? user.name : user.phone} from "${user.role}" to "$newRole"?',
          style: TextStyle(
            fontSize: 14.sp,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: AppTextStyles.bodyFont,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(adminRepositoryProvider)
                  .updateUserRole(user.id, newRole);
              Navigator.pop(ctx);
            },
            child: Text(
              'Confirm',
              style: TextStyle(
                fontFamily: AppTextStyles.bodyFont,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
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
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: EdgeInsets.only(bottom: 10.h),
          height: 80.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      ),
    );
  }
}
