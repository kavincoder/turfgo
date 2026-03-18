import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../providers/admin_provider.dart';

class AdminBookingsDetailScreen extends ConsumerWidget {
  const AdminBookingsDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(allBookingsStreamProvider);

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
          'Bookings',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: AppTextStyles.bodyFont,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Something went wrong')),
        data: (allBookings) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final threeWeeksAgo = today.subtract(const Duration(days: 20));

          // Count by status
          final confirmed = allBookings
              .where((b) => b.status == BookingStatus.confirmed)
              .length;
          final pending = allBookings
              .where((b) => b.status == BookingStatus.pending)
              .length;
          final cancelled = allBookings
              .where((b) => b.status == BookingStatus.cancelled)
              .length;
          final completed = allBookings
              .where((b) => b.status == BookingStatus.completed)
              .length;

          // Build daily booking count for last 21 days
          final dailyCounts = <DateTime, int>{};
          for (int i = 0; i < 21; i++) {
            final day = threeWeeksAgo.add(Duration(days: i));
            dailyCounts[day] = 0;
          }

          for (final b in allBookings) {
            if (b.status == BookingStatus.cancelled) continue;
            try {
              final date = DateTime.parse(b.slotDate);
              final dayKey = DateTime(date.year, date.month, date.day);
              if (dailyCounts.containsKey(dayKey)) {
                dailyCounts[dayKey] = dailyCounts[dayKey]! + 1;
              }
            } catch (_) {}
          }

          final sortedDays = dailyCounts.keys.toList()..sort();
          final values = sortedDays.map((d) => dailyCounts[d]!).toList();
          final maxCount =
              values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);
          final chartMax = maxCount == 0 ? 5.0 : (maxCount * 1.3);

          // Weekly totals
          final week1 = values.sublist(0, 7).fold<int>(0, (s, v) => s + v);
          final week2 = values.sublist(7, 14).fold<int>(0, (s, v) => s + v);
          final week3 = values.sublist(14, 21).fold<int>(0, (s, v) => s + v);
          final total3w = week1 + week2 + week3;

          final weekLabel1 =
              '${DateFormat('MMM d').format(sortedDays[0])} – ${DateFormat('d').format(sortedDays[6])}';
          final weekLabel2 =
              '${DateFormat('MMM d').format(sortedDays[7])} – ${DateFormat('d').format(sortedDays[13])}';
          final weekLabel3 =
              '${DateFormat('MMM d').format(sortedDays[14])} – ${DateFormat('d').format(sortedDays[20])}';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),

                // ── Summary cards ────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Last 3 Weeks',
                          value: '$total3w',
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _SummaryCard(
                          label: 'All Time',
                          value: '${allBookings.length}',
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Status breakdown ─────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    children: [
                      _StatusChip(
                          label: 'Confirmed',
                          count: confirmed,
                          color: AppColors.primary),
                      SizedBox(width: 8.w),
                      _StatusChip(
                          label: 'Pending',
                          count: pending,
                          color: AppColors.warning),
                      SizedBox(width: 8.w),
                      _StatusChip(
                          label: 'Cancelled',
                          count: cancelled,
                          color: AppColors.error),
                      SizedBox(width: 8.w),
                      _StatusChip(
                          label: 'Done',
                          count: completed,
                          color: const Color(0xFF7C3AED)),
                    ],
                  ),
                ),

                SizedBox(height: 24.h),

                // ── Chart ────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Text(
                    'Daily Bookings (Last 3 Weeks)',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTextStyles.bodyFont,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20.w),
                  padding: EdgeInsets.fromLTRB(12.w, 20.h, 16.w, 12.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 220.h,
                    child: BarChart(
                      BarChartData(
                        maxY: chartMax,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            tooltipRoundedRadius: 8,
                            getTooltipItem:
                                (group, groupIndex, rod, rodIndex) {
                              final day = sortedDays[group.x.toInt()];
                              return BarTooltipItem(
                                '${DateFormat('MMM d').format(day)}\n${rod.toY.toInt()} bookings',
                                TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: AppTextStyles.bodyFont,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28.w,
                              interval: chartMax / 4,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox();
                                return Text(
                                  '${value.toInt()}',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: AppColors.grey,
                                    fontFamily: AppTextStyles.bodyFont,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28.h,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx % 3 != 0 || idx >= 21) {
                                  return const SizedBox();
                                }
                                final day = sortedDays[idx];
                                return Padding(
                                  padding: EdgeInsets.only(top: 6.h),
                                  child: Text(
                                    DateFormat('d/M').format(day),
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      color: AppColors.grey,
                                      fontFamily: AppTextStyles.bodyFont,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: chartMax / 4,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: AppColors.border,
                            strokeWidth: 0.5,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(21, (i) {
                          final isCurrentWeek = i >= 14;
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: values[i].toDouble(),
                                width: 8.w,
                                color: isCurrentWeek
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF2563EB)
                                        .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(4.r),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 24.h),

                // ── Weekly breakdown ─────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Text(
                    'Weekly Breakdown',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTextStyles.bodyFont,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                _WeekRow(
                  label: weekLabel3,
                  tag: 'This Week',
                  count: week3,
                  color: const Color(0xFF2563EB),
                ),
                _WeekRow(
                  label: weekLabel2,
                  tag: 'Last Week',
                  count: week2,
                  color: const Color(0xFF7C3AED),
                ),
                _WeekRow(
                  label: weekLabel1,
                  tag: '2 Weeks Ago',
                  count: week1,
                  color: AppColors.primary,
                ),

                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontFamily: AppTextStyles.bodyFont,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
              fontFamily: AppTextStyles.bodyFont,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                fontFamily: AppTextStyles.bodyFont,
                color: color,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                fontFamily: AppTextStyles.bodyFont,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final String label;
  final String tag;
  final int count;
  final Color color;

  const _WeekRow({
    required this.label,
    required this.tag,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 36.h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTextStyles.bodyFont,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                    fontFamily: AppTextStyles.bodyFont,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              fontFamily: AppTextStyles.bodyFont,
              color: color,
            ),
          ),
          Text(
            ' bookings',
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textSecondary,
              fontFamily: AppTextStyles.bodyFont,
            ),
          ),
        ],
      ),
    );
  }
}
