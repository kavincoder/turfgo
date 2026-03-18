import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../providers/admin_provider.dart';

class AdminRevenueScreen extends ConsumerWidget {
  const AdminRevenueScreen({super.key});

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
          'Revenue',
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
          final confirmed = allBookings
              .where((b) => b.status == BookingStatus.confirmed)
              .toList();

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          // Last 21 days (3 weeks)
          final threeWeeksAgo = today.subtract(const Duration(days: 20));

          // Build daily revenue map for last 21 days
          final dailyRevenue = <DateTime, double>{};
          for (int i = 0; i < 21; i++) {
            final day = threeWeeksAgo.add(Duration(days: i));
            dailyRevenue[day] = 0;
          }

          for (final b in confirmed) {
            try {
              final date = DateTime.parse(b.slotDate);
              final dayKey = DateTime(date.year, date.month, date.day);
              if (dailyRevenue.containsKey(dayKey)) {
                dailyRevenue[dayKey] =
                    dailyRevenue[dayKey]! + b.totalAmount;
              }
            } catch (_) {}
          }

          final sortedDays = dailyRevenue.keys.toList()..sort();
          final values = sortedDays.map((d) => dailyRevenue[d]!).toList();
          final maxRevenue =
              values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b);
          final chartMax = maxRevenue == 0 ? 100.0 : maxRevenue * 1.2;

          // Weekly totals
          final week1 = values.sublist(0, 7).fold<double>(0, (s, v) => s + v);
          final week2 = values.sublist(7, 14).fold<double>(0, (s, v) => s + v);
          final week3 =
              values.sublist(14, 21).fold<double>(0, (s, v) => s + v);
          final totalRevenue3w = week1 + week2 + week3;

          // All-time total
          final allTimeRevenue =
              confirmed.fold<double>(0, (s, b) => s + b.totalAmount);

          // Week labels
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

                // ── Total revenue cards ──────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Last 3 Weeks',
                          value: '₹${_formatAmount(totalRevenue3w)}',
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _SummaryCard(
                          label: 'All Time',
                          value: '₹${_formatAmount(allTimeRevenue)}',
                          color: const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24.h),

                // ── Chart ────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Text(
                    'Daily Revenue (Last 3 Weeks)',
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
                  padding:
                      EdgeInsets.fromLTRB(12.w, 20.h, 16.w, 12.h),
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
                            getTooltipItem: (group, groupIndex, rod,
                                rodIndex) {
                              final day = sortedDays[group.x.toInt()];
                              return BarTooltipItem(
                                '${DateFormat('MMM d').format(day)}\n₹${rod.toY.toInt()}',
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
                              reservedSize: 42.w,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox();
                                return Padding(
                                  padding: EdgeInsets.only(right: 4.w),
                                  child: Text(
                                    '₹${_formatCompact(value)}',
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
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28.h,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                // Show every 3rd day label
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
                                toY: values[i],
                                width: 8.w,
                                color: isCurrentWeek
                                    ? AppColors.primary
                                    : AppColors.primary
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
                  amount: week3,
                  color: AppColors.primary,
                ),
                _WeekRow(
                  label: weekLabel2,
                  tag: 'Last Week',
                  amount: week2,
                  color: const Color(0xFF2563EB),
                ),
                _WeekRow(
                  label: weekLabel1,
                  tag: '2 Weeks Ago',
                  amount: week1,
                  color: const Color(0xFF7C3AED),
                ),

                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toInt().toString();
  }

  static String _formatCompact(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toInt().toString();
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
              fontSize: 24.sp,
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

class _WeekRow extends StatelessWidget {
  final String label;
  final String tag;
  final double amount;
  final Color color;

  const _WeekRow({
    required this.label,
    required this.tag,
    required this.amount,
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
            '₹${amount.toInt()}',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              fontFamily: AppTextStyles.bodyFont,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
