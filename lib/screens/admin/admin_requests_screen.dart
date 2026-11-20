import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants.dart';
import '../../models/owner_request.dart';
import '../../providers/owner_request_provider.dart';

class AdminRequestsScreen extends ConsumerWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(allOwnerRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Owner Requests',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: requestsAsync.when(
        loading: () => _buildShimmer(),
        error: (_, __) =>
            const Center(child: Text('Something went wrong')),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded,
                      size: 48.sp, color: AppColors.grey),
                  SizedBox(height: 12.h),
                  Text(
                    'No owner requests yet',
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

          // Show pending first, then approved, then rejected
          final sorted = [...requests]..sort((a, b) {
              const order = {
                RequestStatus.pending: 0,
                RequestStatus.approved: 1,
                RequestStatus.rejected: 2,
              };
              final cmp =
                  (order[a.status] ?? 3).compareTo(order[b.status] ?? 3);
              if (cmp != 0) return cmp;
              return b.createdAt.compareTo(a.createdAt);
            });

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: sorted.length,
            itemBuilder: (_, i) =>
                _RequestCard(request: sorted[i]),
          );
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          margin: EdgeInsets.only(bottom: 12.h),
          height: 180.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  final OwnerRequest request;
  const _RequestCard({required this.request});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _loading = false;

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(ownerRequestRepositoryProvider)
          .approveRequest(widget.request.id);
    } catch (e, st) {
      debugPrint('Approve owner request failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to approve. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _RejectDialog(),
    );
    if (reason == null) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(ownerRequestRepositoryProvider)
          .rejectRequest(widget.request.id, reason);
    } catch (e, st) {
      debugPrint('Reject owner request failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to reject. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final color = RequestStatus.color(r.status);
    final isPending = r.status == RequestStatus.pending;

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
          // Header — turf name + status
          Row(
            children: [
              Expanded(
                child: Text(
                  r.turfName,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTextStyles.bodyFont,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  RequestStatus.label(r.status),
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTextStyles.bodyFont,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 10.h),

          // Owner info
          Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 14.sp, color: AppColors.textSecondary),
              SizedBox(width: 4.w),
              Text(
                '${r.userName.isNotEmpty ? r.userName : "Unknown"} · ${r.userPhone}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  fontFamily: AppTextStyles.bodyFont,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),

          // Location
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 14.sp, color: AppColors.textSecondary),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  '${r.area}, ${r.address}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    fontFamily: AppTextStyles.bodyFont,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),

          // Details row
          Row(
            children: [
              _infoChip(
                  Icons.sports_soccer_rounded, r.sports.join(', ')),
              SizedBox(width: 10.w),
              _infoChip(Icons.currency_rupee_rounded,
                  '${r.pricePerHour.toInt()}/hr'),
              SizedBox(width: 10.w),
              _infoChip(Icons.access_time_rounded,
                  '${r.openTime}–${r.closeTime}'),
            ],
          ),

          SizedBox(height: 8.h),

          // Photos preview
          if (r.photos.isNotEmpty) ...[
            SizedBox(
              height: 60.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: r.photos.length,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.only(right: 6.w),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.network(
                      r.photos[i],
                      width: 60.w,
                      height: 60.h,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60.w,
                        height: 60.h,
                        color: AppColors.surface,
                        child: Icon(Icons.image,
                            size: 20.sp, color: AppColors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
          ],

          // Date
          Text(
            'Submitted ${DateFormat('MMM d, yyyy').format(r.createdAt)}',
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.grey,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),

          // Rejection reason
          if (r.status == RequestStatus.rejected &&
              r.rejectionReason != null) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14.sp, color: AppColors.error),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      r.rejectionReason!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.error,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons for pending
          if (isPending) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: Size(0, 40.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      textStyle: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _approve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, 40.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      textStyle: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTextStyles.bodyFont,
                      ),
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.sp, color: AppColors.grey),
        SizedBox(width: 3.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.sp,
            color: AppColors.textSecondary,
            fontFamily: AppTextStyles.bodyFont,
          ),
        ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r)),
      title: Text(
        'Reject Request',
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          fontFamily: AppTextStyles.bodyFont,
        ),
      ),
      content: TextField(
        controller: _ctrl,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Reason for rejection (optional)',
          hintStyle: TextStyle(
            color: AppColors.grey,
            fontFamily: AppTextStyles.bodyFont,
            fontSize: 14.sp,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
        style: TextStyle(
          fontFamily: AppTextStyles.bodyFont,
          fontSize: 14.sp,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
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
            Navigator.pop(
              context,
              _ctrl.text.trim().isNotEmpty
                  ? _ctrl.text.trim()
                  : 'Request rejected',
            );
          },
          child: Text(
            'Reject',
            style: TextStyle(
              fontFamily: AppTextStyles.bodyFont,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
        ),
      ],
    );
  }
}
